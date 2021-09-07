//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import struct NIO.CircularBuffer

/// A buffer that handles encoding of Swift types into IMAP commands/responses that
/// will be sent/recieved by clients and servers.
@_spi(NIOIMAPInternal) public struct EncodeBuffer: Hashable {
    /// Used to define if the buffer should act as a client or server.
    public enum Mode: Hashable {
        /// Act as a client using the given `CommandEncodingOptions`.
        case client(options: CommandEncodingOptions)

        /// Act as a server using the given `ResponseEncodingOptions`.
        case server(streamingAttributes: Bool, options: ResponseEncodingOptions)
    }

    internal var mode: Mode
    @usableFromInline internal var buffer: ByteBuffer
    @usableFromInline internal var stopPoints: CircularBuffer<Int> = []

    init(_ buffer: ByteBuffer, mode: Mode) {
        self.buffer = buffer
        self.mode = mode
    }
}

extension EncodeBuffer {
    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    static func clientEncodeBuffer(buffer: ByteBuffer, options: CommandEncodingOptions) -> EncodeBuffer {
        EncodeBuffer(buffer, mode: .client(options: options))
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    static func clientEncodeBuffer(buffer: ByteBuffer, capabilities: [Capability]) -> EncodeBuffer {
        clientEncodeBuffer(buffer: buffer, options: CommandEncodingOptions(capabilities: capabilities))
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    static func serverEncodeBuffer(buffer: ByteBuffer, options: ResponseEncodingOptions) -> EncodeBuffer {
        EncodeBuffer(buffer, mode: .server(streamingAttributes: false, options: options))
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    static func serverEncodeBuffer(buffer: ByteBuffer, capabilities: [Capability]) -> EncodeBuffer {
        serverEncodeBuffer(buffer: buffer, options: ResponseEncodingOptions(capabilities: capabilities))
    }
}

extension EncodeBuffer {
    /// Represents a piece of data that is ready to be written to the network.
    public struct Chunk: Hashable {
        /// The data that is ready to be written.
        public var bytes: ByteBuffer

        /// Is a continuation request expected before this data can be written?
        public var waitForContinuation: Bool
    }

    /// Gets the next chunk that is ready to be written to the network.
    /// - returns: The next chunk that is ready to be written.
    public mutating func nextChunk() -> Chunk {
        self.nextChunk(allowEmptyChunk: true)
    }

    /// Gets the next chunk that is ready to be written to the network.
    /// *NOTE*: Use This function with caution. You probably shouldn't be using it, using nextChunk() instead.
    /// - returns: The next chunk that is ready to be written.
    @_spi(NIOIMAPInternal) public mutating func nextChunk(allowEmptyChunk: Bool) -> Chunk {
        switch self.mode {
        case .client:
            if let stopPoint = self.stopPoints.popFirst() {
                return .init(bytes: self.buffer.readSlice(length: stopPoint - self.buffer.readerIndex)!,
                             waitForContinuation: true)
            } else {
                precondition(allowEmptyChunk || self.buffer.readableBytes > 0, "No next chunk to send.")
                return .init(bytes: self.buffer.readSlice(length: self.buffer.readableBytes)!, waitForContinuation: false)
            }
        case .server:
            return .init(bytes: self.buffer.readSlice(length: self.buffer.readableBytes)!, waitForContinuation: false)
        }
    }

    /// Marks the end of the current `Chunk`.
    @discardableResult
    public mutating func markStopPoint() -> Int {
        if case .client = mode {
            stopPoints.append(buffer.writerIndex)
        }
        return 0
    }
}

extension EncodeBuffer {
    /// Writes a raw `String` to the buffer.
    /// - parameter string: The string to write.
    /// - returns: The number of bytes written - always `string.utf8.count`.
    @discardableResult
    @inlinable
    public mutating func writeString(_ string: String) -> Int {
        self.buffer.writeString(string)
    }

    /// Writes raw bytes to the buffer.
    /// - parameter buffer: The bytes to write.
    /// - returns: The number of bytes written - always equal to the size of `bytes`.
    @discardableResult
    @inlinable
    public mutating func writeBytes<Bytes: Sequence>(_ bytes: Bytes) -> Int where Bytes.Element == UInt8 {
        self.buffer.writeBytes(bytes)
    }

    /// Writes a `ByteBuffer` to the buffer.
    /// - parameter buffer: The `ByteBuffer` to write.
    /// - returns: The number of bytes written - always equal to `buffer.readableBytes`.
    @discardableResult
    @inlinable
    public mutating func writeBuffer(_ buffer: inout ByteBuffer) -> Int {
        self.buffer.writeBuffer(&buffer)
    }

    /// Erases all data from the buffer.
    @inlinable
    public mutating func clear() {
        self.stopPoints.removeAll()
        self.buffer.clear()
    }
}
