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

/// Encodes IMAP server responses into wire format ready for transmission to an IMAP client.
///
/// `ResponseEncodeBuffer` is the primary interface for encoding responses from the server side.
/// Unlike ``CommandEncodeBuffer`` which handles chunking for synchronizing literals,
/// `ResponseEncodeBuffer` returns all encoded data in a single operation, which is
/// appropriate for server-to-client responses that don't require continuation handshakes.
///
/// ## Usage Example
///
/// ```swift
/// var buffer = ResponseEncodeBuffer(
///     options: ResponseEncodingOptions(),
///     loggingMode: false
/// )
/// // Encode response data into buffer
/// let encoded = buffer.readBytes()  // Get all encoded data
/// ```
///
/// ## Where the bytes go
///
/// This is the type a server creates; it owns an ``EncoderOutputBuffer``, the sink the encoded bytes
/// are appended to, chosen once with the `sink:` argument and never named again. Leaving it out gives
/// an ``IMAPOutputBuffer``, which is the right answer unless the bytes have to land somewhere
/// specific — see ``EncoderOutputBuffer`` for the choice. ``readBytes()`` hands back an
/// ``IMAPBufferList``, which converts to a `DispatchData`, to `ByteBuffer`s, or to one contiguous copy.
///
/// - SeeAlso: ``CommandEncodeBuffer``, ``ResponseEncodingOptions``
public struct ResponseEncodeBuffer {
    var buffer: EncodeBuffer

    /// Retrieves all encoded data from the buffer for transmission.
    ///
    /// After calling this method, the buffer is cleared and ready for encoding the
    /// next response. This is typically called after encoding a complete response
    /// to retrieve the wire-format bytes for sending to the client.
    ///
    /// - Returns: All encoded response data, as one or more regions — usually one.
    public mutating func readBytes() -> IMAPBufferList {
        let bytes = self.buffer.nextChunk().bytes
        // A zero-*bytes* check: a server-mode chunk takes everything, so nothing may be left behind.
        precondition(self.buffer.pendingByteCount == 0)
        // Clearing also releases the sink's storage, which matters because a server handler keeps one
        // of these for the lifetime of a connection.
        self.buffer.clear()
        return bytes
    }

    /// Creates a new response encoding buffer with explicit options.
    ///
    /// - Parameters:
    ///   - sink: Where the encoded bytes are appended. Defaults to an ``IMAPOutputBuffer``, which
    ///     is the right choice unless the bytes have to land somewhere specific.
    ///   - options: The ``ResponseEncodingOptions`` controlling how strings and other
    ///     protocol elements are encoded.
    ///   - loggingMode: When `true`, binary data is replaced with placeholders like
    ///     `[N bytes]` for safe logging. Defaults to `false`.
    public init(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        options: ResponseEncodingOptions,
        loggingMode: Bool
    ) {
        self.buffer = .serverEncodeBuffer(sink: sink, options: options, loggingMode: loggingMode)
    }

    /// Wraps an existing ``EncodeBuffer``, so response writers can be driven over a buffer somebody
    /// else created.
    ///
    /// - Parameter buffer: The buffer to write to. Must be in server mode.
    internal init(_ buffer: EncodeBuffer) {
        self.buffer = buffer
    }
}

// MARK: - Sendability

/// `ResponseEncodeBuffer` is deliberately **not** `Sendable`, because the ``EncoderOutputBuffer`` it
/// writes into is not: see ``EncodeBuffer``. The bytes ``readBytes()`` hands out *are* `Sendable`.
@available(*, unavailable)
extension ResponseEncodeBuffer: Sendable {}

extension ResponseEncodeBuffer {
    /// Creates a new response encoding buffer from server capabilities.
    ///
    /// Converts a list of ``Capability`` values into ``ResponseEncodingOptions``,
    /// which enables capability-dependent encoding options if the server advertises them.
    ///
    /// - Parameters:
    ///   - sink: Where the encoded bytes are appended. Defaults to an ``IMAPOutputBuffer``.
    ///   - capabilities: Server capabilities for context. These may be used to configure
    ///     encoding options if needed.
    ///   - loggingMode: When `true`, binary data is replaced with placeholders like
    ///     `[N bytes]` for safe logging. Defaults to `false`.
    public init(
        sink: some EncoderOutputBuffer = IMAPOutputBuffer(),
        capabilities: [Capability],
        loggingMode: Bool
    ) {
        self.buffer = .serverEncodeBuffer(sink: sink, capabilities: capabilities, loggingMode: loggingMode)
    }
}

extension ResponseEncodeBuffer {
    /// Call the closure with a buffer, return the result as a String.
    ///
    /// Used for implementing ``CustomDebugStringConvertible`` conformance.
    static func makeDescription(loggingMode: Bool, _ closure: (inout ResponseEncodeBuffer) -> Void) -> String {
        var options = ResponseEncodingOptions()
        options.useQuotedString = true
        var buffer = ResponseEncodeBuffer(options: options, loggingMode: loggingMode)
        closure(&buffer)
        return String(bestEffortDecodingUTF8Bytes: buffer.buffer.makePendingBufferList().copiedBytes())
    }
}

// MARK: - Encode ContinuationRequest

extension ResponseEncodeBuffer {
    /// Writes a `ContinuationRequest` in the format *+ <data>\r\n*
    /// - parameter data: The continuation request.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeContinuationRequest(_ data: ContinuationRequest) -> Int {
        var size = 0
        size += self.buffer.writeString("+ ")
        switch data {
        case .responseText(let text):
            size += self.buffer.writeResponseText(text)
        case .data(let base64):
            size += self.buffer.writeBufferAsBase64(base64)
        }
        size += self.buffer.writeString("\r\n")
        return size
    }
}

// MARK: - Encode Response

extension ResponseEncodeBuffer {
    /// Writes a `Response`.
    /// - parameter response: The response to write.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeResponse(_ response: Response) -> Int {
        switch response {
        case .untagged(let resp):
            return self.buffer.writeResponseData(resp)
        case .fetch(let response):
            return self.writeFetchResponse(response)
        case .tagged(let end):
            return self.buffer.writeTaggedResponse(end)
        case .fatal(let fatal):
            return self.buffer.writeResponseFatal(fatal)
        case .authenticationChallenge(let bytes):
            return self.writeAuthenticationChallenge(bytes)
        case .idleStarted:
            return self.writeContinuationRequest(.responseText(.init(code: nil, text: "idling")))
        }
    }

    @discardableResult mutating func writeAuthenticationChallenge(_ bytes: ByteBuffer) -> Int {
        let base64 = Base64.encodeBytes(bytes: bytes.readableBytesView)
        return self.buffer.writeString("+ ") + self.buffer.writeBytes(base64) + self.buffer.writeString("\r\n")
    }

    @discardableResult mutating func writeFetchResponse(_ response: FetchResponse) -> Int {
        switch response {
        case .start(let num):
            return self.buffer.writeString("* ") + self.buffer.writeSequenceNumber(num)
                + self.buffer.writeString(" FETCH (")
        case .startUID(let num):
            return self.buffer.writeString("* ") + self.buffer.writeMessageIdentifier(num)
                + self.buffer.writeString(" UIDFETCH (")
        case .simpleAttribute(let att):
            guard case .server(streamingAttributes: let streamingAttributes, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            guard streamingAttributes else {
                self.buffer.mode = .server(streamingAttributes: true, options: options)
                return self.buffer.writeMessageAttribute(att)
            }
            return self.buffer.writeSpace() + self.buffer.writeMessageAttribute(att)
        case .streamingBegin(let type, let size):
            guard case .server(streamingAttributes: let streamingAttributes, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            guard streamingAttributes else {
                self.buffer.mode = .server(streamingAttributes: true, options: options)
                return self.writeStreamingKind(type, size: size)
            }
            return self.buffer.writeSpace() + self.writeStreamingKind(type, size: size)
        case .streamingBytes(var bytes):
            return self.buffer.writeBuffer(&bytes)
        case .streamingEnd:
            return 0  // do nothing, this is a "fake" event
        case .finish:
            guard case .server(_, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            self.buffer.mode = .server(streamingAttributes: false, options: options)
            return self.buffer.writeString(")\r\n")
        }
    }

    @discardableResult mutating func writeStreamingKind(_ kind: StreamingKind, size: Int) -> Int {
        self.buffer.writeStreamingKind(kind) + self.buffer.writeSpace()
            + self.buffer.writeLiteralHeader(byteCount: size)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeStreamingKind(_ kind: StreamingKind) -> Int {
        switch kind {
        case .binary:
            return self.writeString("BINARY")
        case .body(let section, let offset):
            return self.writeString("BODY") + self.writeSection(section)
                + writeIfExists(offset) { offset in
                    self.writeByte(UInt8(ascii: "<")) + self.writeDecimal(offset) + self.writeByte(UInt8(ascii: ">"))
                }
        case .rfc822:
            return self.writeString("RFC822")
        case .rfc822Text:
            return self.writeString("RFC822.TEXT")
        case .rfc822Header:
            return self.writeString("RFC822.HEADER")
        }
    }
}
