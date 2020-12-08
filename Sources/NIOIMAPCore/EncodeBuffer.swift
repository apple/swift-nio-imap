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
public struct EncodeBuffer {
    
    /// Used to define if the buffer should act as a client or server.
    public enum Mode: Equatable {
        
        /// Act as a client using the given `CommandEncodingOptions`.
        case client(options: CommandEncodingOptions)
        
        /// Act as a server using the given `ResponseEncodingOptions`.
        case server(streamingAttributes: Bool, options: ResponseEncodingOptions)
    }

    internal var mode: Mode
    @usableFromInline internal var _buffer: ByteBuffer
    @usableFromInline internal var _stopPoints: CircularBuffer<Int> = []

    init(_ buffer: ByteBuffer, mode: Mode) {
        self._buffer = buffer
        self.mode = mode
    }
}

extension EncodeBuffer {
    
    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    public static func clientEncodeBuffer(buffer: ByteBuffer, options: CommandEncodingOptions) -> EncodeBuffer {
        EncodeBuffer(buffer, mode: .client(options: options))
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    public static func clientEncodeBuffer(buffer: ByteBuffer, capabilities: [Capability]) -> EncodeBuffer {
        clientEncodeBuffer(buffer: buffer, options: CommandEncodingOptions(capabilities: capabilities))
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    public static func serverEncodeBuffer(buffer: ByteBuffer, options: ResponseEncodingOptions) -> EncodeBuffer {
        EncodeBuffer(buffer, mode: .server(streamingAttributes: false, options: options))
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    public static func serverEncodeBuffer(buffer: ByteBuffer, capabilities: [Capability]) -> EncodeBuffer {
        serverEncodeBuffer(buffer: buffer, options: ResponseEncodingOptions(capabilities: capabilities))
    }
}

extension EncodeBuffer {
    public struct Chunk {
        public var bytes: ByteBuffer
        public var waitForContinuation: Bool
    }

    public mutating func nextChunk() -> Chunk {
        switch self.mode {
        case .client:
            if let stopPoint = self._stopPoints.popFirst() {
                return .init(bytes: self._buffer.readSlice(length: stopPoint - self._buffer.readerIndex)!,
                             waitForContinuation: stopPoint != self._buffer.writerIndex)
            } else {
                precondition(self._buffer.readableBytes > 0, "No next chunk to send.")
                return .init(bytes: self._buffer.readSlice(length: self._buffer.readableBytes)!, waitForContinuation: false)
            }
        case .server:
            return .init(bytes: self._buffer.readSlice(length: self._buffer.readableBytes)!, waitForContinuation: false)
        }
    }

    @discardableResult
    public mutating func markStopPoint() -> Int {
        if case .client = mode {
            _stopPoints.append(_buffer.writerIndex)
        }
        return 0
    }
}

extension EncodeBuffer {
    @discardableResult
    @inlinable
    public mutating func writeString(_ string: String) -> Int {
        self._buffer.writeString(string)
    }

    @discardableResult
    @inlinable
    public mutating func writeBytes<Bytes: Sequence>(_ bytes: Bytes) -> Int where Bytes.Element == UInt8 {
        return self._buffer.writeBytes(bytes)
    }

    @discardableResult
    @inlinable
    public mutating func writeBuffer(_ buffer: inout ByteBuffer) -> Int {
        self._buffer.writeBuffer(&buffer)
    }

    @inlinable
    public mutating func clear() {
        self._stopPoints.removeAll()
        self._buffer.clear()
    }
}
