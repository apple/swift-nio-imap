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

/// A buffer for encoding IMAP protocol messages into wire format.
///
/// `EncodeBuffer` is the core infrastructure for converting Swift types into bytes
/// that can be transmitted over the network. It wraps a `ByteBuffer` and tracks
/// encoding state, supporting both client commands and server responses.
///
/// This type is part of the internal SPI and is primarily used by:
/// - ``CommandEncodeBuffer`` for encoding client commands
/// - ``ResponseEncodeBuffer`` for encoding server responses
///
/// The buffer can operate in two modes via the ``Mode`` enum:
/// - **Client mode**: Uses ``CommandEncodingOptions`` to determine how to encode literals,
///   strings, and other protocol elements
/// - **Server mode**: Uses ``ResponseEncodingOptions`` to format server responses
///
/// ## Chunking and Continuation
///
/// The buffer supports splitting encoded data into "chunks" separated by continuation
/// points. This enables proper handling of IMAP's synchronizing literals, where the
/// server must send a `+` continuation request before the client can send more data.
/// The ``nextChunk()`` method retrieves the next chunk and indicates whether a
/// continuation response is expected.
///
/// - SeeAlso: ``CommandEncodeBuffer``, ``ResponseEncodeBuffer``
@_spi(NIOIMAPInternal) public struct EncodeBuffer: Hashable, Sendable {
    /// Determines whether the buffer encodes for a client or server.
    ///
    /// This affects how the buffer formats protocol elements like literals, strings,
    /// and response codes. The mode also carries encoding options specific to each role.
    public enum Mode: Hashable, Sendable {
        /// Encodes client commands using the specified options.
        ///
        /// When in client mode, the buffer formats command data according to the
        /// options, which control whether to use quoted strings, synchronizing literals,
        /// non-synchronizing literals, and binary literals.
        ///
        /// - Parameter options: Configuration for command encoding
        case client(options: CommandEncodingOptions)

        /// Encodes server responses using the specified options.
        ///
        /// - Parameter streamingAttributes: A flag tracking whether streaming attributes
        ///   are currently being written (used internally for FETCH response formatting)
        /// - Parameter options: Configuration for response encoding
        case server(streamingAttributes: Bool, options: ResponseEncodingOptions)
    }

    /// Enables logging mode, which obscures binary data for display purposes.
    ///
    /// When `true`, methods like ``writeBytes(_:)`` and ``writeBuffer(_:)`` will
    /// write placeholder text like `[N bytes]` instead of the actual binary content.
    /// This is useful for logging and debugging without exposing sensitive data.
    public var loggingMode: Bool

    internal var mode: Mode
    @usableFromInline internal var buffer: ByteBuffer
    @usableFromInline internal var stopPoints: CircularBuffer<Int> = []

    init(_ buffer: ByteBuffer, mode: Mode, loggingMode: Bool) {
        self.buffer = buffer
        self.mode = mode
        self.loggingMode = loggingMode
    }
}

extension EncodeBuffer {
    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    static func clientEncodeBuffer(
        buffer: ByteBuffer,
        options: CommandEncodingOptions,
        loggingMode: Bool
    ) -> EncodeBuffer {
        EncodeBuffer(buffer, mode: .client(options: options), loggingMode: loggingMode)
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for client use.
    static func clientEncodeBuffer(buffer: ByteBuffer, capabilities: [Capability], loggingMode: Bool) -> EncodeBuffer {
        clientEncodeBuffer(
            buffer: buffer,
            options: CommandEncodingOptions(capabilities: capabilities),
            loggingMode: loggingMode
        )
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    static func serverEncodeBuffer(
        buffer: ByteBuffer,
        options: ResponseEncodingOptions,
        loggingMode: Bool
    ) -> EncodeBuffer {
        EncodeBuffer(buffer, mode: .server(streamingAttributes: false, options: options), loggingMode: loggingMode)
    }

    /// Creates a new `EncodeBuffer` suitable for a client to write commands.
    /// - parameter buffer: An initial `ByteBuffer` to write to. Note that this is copied and not taken as `inout`.
    /// - parameter options: Configuration to use when writing.
    /// - returns: A new `EncodeBuffer` configured for server use.
    static func serverEncodeBuffer(buffer: ByteBuffer, capabilities: [Capability], loggingMode: Bool) -> EncodeBuffer {
        serverEncodeBuffer(
            buffer: buffer,
            options: ResponseEncodingOptions(capabilities: capabilities),
            loggingMode: loggingMode
        )
    }
}

extension EncodeBuffer {
    /// Call the closure with a buffer, return the result as a String.
    ///
    /// Used for implementing ``CustomDebugStringConvertible`` conformance.
    static func makeDescription(_ closure: (inout EncodeBuffer) -> Void) -> String {
        var options = CommandEncodingOptions.rfc3501
        options.useQuotedString = true
        options.useSynchronizingLiteral = false
        options.useNonSynchronizingLiteralPlus = true
        var buffer = EncodeBuffer.clientEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: false)
        closure(&buffer)
        return String(bestEffortDecodingUTF8Bytes: buffer.buffer.readableBytesView)
    }
}

extension EncodeBuffer {
    /// A portion of encoded data ready to be transmitted.
    ///
    /// IMAP requires careful sequencing when using synchronizing literals. After encoding
    /// a command with a literal, the buffer chunks the data into segments: one that ends
    /// before the literal, then waits for a continuation response, then sends the literal
    /// data and any remaining command.
    ///
    /// Each `Chunk` represents a portion of data that is ready to send, along with
    /// metadata about whether a continuation response is expected.
    public struct Chunk: Hashable, Sendable {
        /// The encoded bytes ready to write to the network.
        ///
        /// This buffer contains the next portion of IMAP protocol data to transmit.
        public var bytes: ByteBuffer

        /// Whether a continuation request (`+`) should be expected before sending the next chunk.
        ///
        /// When `true`, the sender must wait for the server to send a `+` continuation
        /// response before calling ``nextChunk()`` again. This synchronization is required
        /// by RFC 3501 for commands containing literals.
        ///
        /// - SeeAlso: ``ContinuationRequest``
        public var waitForContinuation: Bool
    }

    @_spi(NIOIMAPInternal) var hasChunks: Bool {
        self.stopPoints.count > 0
    }

    /// Retrieves the next chunk of encoded data ready to transmit.
    ///
    /// In client mode with synchronizing literals, this may return multiple chunks with
    /// ``Chunk.waitForContinuation`` set to `true` between chunks, requiring the caller
    /// to pause and wait for the server's `+` continuation request.
    ///
    /// In server mode, this always returns all remaining data in a single chunk with
    /// ``Chunk.waitForContinuation`` set to `false`.
    ///
    /// - Returns: The next ``Chunk`` of data to transmit.
    public mutating func nextChunk() -> Chunk {
        self.nextChunk(allowEmptyChunk: true)
    }

    /// Gets the next chunk that is ready to be written to the network.
    /// *NOTE*: Use This function with caution. You probably shouldn't be using it, using nextChunk() instead.
    /// - returns: The next chunk that is ready to be written.
    @_spi(NIOIMAPInternal) public mutating func nextChunk(allowEmptyChunk: Bool) -> Chunk {
        switch self.mode {
        case .client:
            guard let stopPoint = self.stopPoints.popFirst() else {
                precondition(allowEmptyChunk || self.buffer.readableBytes > 0, "No next chunk to send.")
                return .init(
                    bytes: self.buffer.readSlice(length: self.buffer.readableBytes)!,
                    waitForContinuation: false
                )
            }
            return .init(
                bytes: self.buffer.readSlice(length: stopPoint - self.buffer.readerIndex)!,
                waitForContinuation: stopPoint != self.buffer.writerIndex
            )
        case .server:
            return .init(bytes: self.buffer.readSlice(length: self.buffer.readableBytes)!, waitForContinuation: false)
        }
    }

    /// Marks the end of a command, potentially creating a stop point for chunking.
    ///
    /// In client mode, this sets a stop point that ``nextChunk()`` uses to determine
    /// chunk boundaries. This is necessary for proper handling of synchronizing literals,
    /// where each chunk must be separated by a continuation request/response cycle.
    ///
    /// In server mode, this call has no effect (server responses don't use stop points).
    ///
    /// - Returns: Always returns `0` (for compatibility with writer method conventions).
    @discardableResult
    public mutating func markStopPoint() -> Int {
        if case .client = mode {
            stopPoints.append(buffer.writerIndex)
        }
        return 0
    }
}

extension EncodeBuffer {
    /// Writes a string to the buffer in UTF-8 encoding.
    ///
    /// - Parameter string: The string to write.
    /// - Returns: The number of bytes written (equals `string.utf8.count`).
    @discardableResult
    @inlinable
    public mutating func writeString(_ string: String) -> Int {
        self.buffer.writeString(string)
    }

    /// Writes raw bytes to the buffer.
    ///
    /// When ``loggingMode`` is enabled, this writes a placeholder like `[N bytes]`
    /// instead of the actual binary data, useful for debugging without exposing sensitive content.
    ///
    /// - Parameter bytes: The bytes to write.
    /// - Returns: The number of bytes written (in logging mode, this is the length of the placeholder).
    @discardableResult
    @inlinable
    public mutating func writeBytes<Bytes: Sequence>(_ bytes: Bytes) -> Int where Bytes.Element == UInt8 {
        guard loggingMode else {
            return self.buffer.writeBytes(bytes)
        }
        return self.buffer.writeString("[\(Array(bytes).count) bytes]")
    }

    /// Writes a `ByteBuffer` to the buffer.
    ///
    /// When ``loggingMode`` is enabled, this writes a placeholder like `[N bytes]`
    /// instead of the actual binary data.
    ///
    /// - Parameter buffer: The buffer to write.
    /// - Returns: The number of bytes written (in logging mode, this is the length of the placeholder).
    @discardableResult
    @inlinable
    public mutating func writeBuffer(_ buffer: inout ByteBuffer) -> Int {
        guard loggingMode else {
            return self.buffer.writeBuffer(&buffer)
        }
        return self.buffer.writeString("[\(buffer.readableBytes) bytes]")
    }

    /// Erases all data from the buffer and resets the chunk tracking.
    ///
    /// - Note: This invalidates any previously obtained ``Chunk`` values.
    @inlinable
    public mutating func clear() {
        self.stopPoints.removeAll()
        self.buffer.clear()
    }
}

extension EncodeBuffer {
    mutating func withoutLoggingMode<R>(_ closure: (inout EncodeBuffer) -> R) -> R {
        let old = self.loggingMode
        defer {
            self.loggingMode = old
        }
        self.loggingMode = false
        return closure(&self)
    }
}
