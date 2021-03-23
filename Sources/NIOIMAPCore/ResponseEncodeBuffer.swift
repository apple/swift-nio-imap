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

/// Used to write responses in preparation for sending down a network.
public struct ResponseEncodeBuffer {
    private var buffer: _EncodeBuffer

    /// Data that is waiting to be sent.
    public mutating func readBytes() -> ByteBuffer {
        let buffer = self.buffer._nextChunk()._bytes
        precondition(self.buffer._buffer.readableBytes == 0)
        self.buffer._buffer.clear()
        return buffer
    }

    /// Creates a new `ResponseEncodeBuffer` from an initial `ByteBuffer` and configuration.
    /// - parameter buffer: The inital `ByteBuffer` to use. Note that this is copied, not taken as `inout`.
    /// - parameter options: The `ResponseEncodingOptions` to use when writing responses.
    public init(buffer: ByteBuffer, options: ResponseEncodingOptions) {
        self.buffer = ._serverEncodeBuffer(buffer: buffer, options: options)
    }
}

extension ResponseEncodeBuffer {
    /// Creates a new `ResponseEncodeBuffer` from an initial `ByteBuffer` and configuration.
    /// - parameter buffer: The inital `ByteBuffer` to use. Note that this is copied, not taken as `inout`.
    /// - parameter capabilities: Server capabilites to use when writing responses. These will be converted into a `ResponseEncodingOptions`.
    public init(buffer: ByteBuffer, capabilities: [Capability]) {
        self.buffer = ._serverEncodeBuffer(buffer: buffer, capabilities: capabilities)
    }
}

// MARK: - Encode ContinuationRequest

extension ResponseEncodeBuffer {
    /// Writes a `ContinuationRequest` in the format *+ <data>\r\n*
    /// - parameter data: The continuation request.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeContinuationRequest(_ data: ContinuationRequest) -> Int {
        var size = 0
        size += self.buffer._writeString("+ ")
        switch data {
        case .responseText(let text):
            size += self.buffer.writeResponseText(text)
        case .data(let base64):
            size += self.buffer.writeBufferAsBase64(base64)
        }
        size += self.buffer._writeString("\r\n")
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
        case .untaggedResponse(let resp):
            return self.buffer.writeResponseData(resp)
        case .fetchResponse(let response):
            return self.writeFetchResponse(response)
        case .taggedResponse(let end):
            return self.buffer.writeTaggedResponse(end)
        case .fatalResponse(let fatal):
            return self.buffer.writeResponseFatal(fatal)
        case .authenticationChallenge(let bytes):
            return self.writeAuthenticationChallenge(bytes)
        }
    }

    @discardableResult mutating func writeAuthenticationChallenge(_ bytes: ByteBuffer) -> Int {
        let base64 = Base64.encodeBytes(bytes: bytes.readableBytesView)
        return self.buffer._writeString("+ ") +
            self.buffer._writeBytes(base64) +
            self.buffer._writeString("\r\n")
    }

    @discardableResult mutating func writeFetchResponse(_ response: FetchResponse) -> Int {
        switch response {
        case .start(let num):
            return self.buffer._writeString("* ") +
                self.buffer.writeSequenceNumber(num) +
                self.buffer._writeString(" FETCH (")
        case .simpleAttribute(let att):
            guard case .server(streamingAttributes: let streamingAttributes, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            if streamingAttributes {
                return self.buffer.writeSpace() + self.buffer.writeMessageAttribute(att)
            } else {
                self.buffer.mode = .server(streamingAttributes: true, options: options)
                return self.buffer.writeMessageAttribute(att)
            }
        case .streamingBegin(let type, let size):
            guard case .server(streamingAttributes: let streamingAttributes, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            if streamingAttributes {
                return self.buffer.writeSpace() + self.writeStreamingKind(type, size: size)
            } else {
                self.buffer.mode = .server(streamingAttributes: true, options: options)
                return self.writeStreamingKind(type, size: size)
            }
        case .streamingBytes(var bytes):
            return self.buffer._writeBuffer(&bytes)
        case .streamingEnd:
            return 0 // do nothing, this is a "fake" event
        case .finish:
            guard case .server(_, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            self.buffer.mode = .server(streamingAttributes: false, options: options)
            return self.buffer._writeString(")\r\n")
        }
    }

    @discardableResult mutating func writeStreamingKind(_ type: StreamingKind, size: Int) -> Int {
        switch type {
        case .binary:
            return self.buffer._writeString("BINARY {\(size)}\r\n")
        case .body(let section, let offset):
            return self.buffer._writeString("BODY") +
                self.buffer.writeSection(section) +
                self.buffer.writeIfExists(offset) { offset in
                    self.buffer._writeString("<\(offset)>")
                } +
                self.buffer.writeSpace() +
                self.buffer._writeString("{\(size)}\r\n")
        case .rfc822:
            return self.buffer._writeString("RFC822 {\(size)}\r\n")
        case .rfc822Text:
            return self.buffer._writeString("RFC822.TEXT {\(size)}\r\n")
        case .rfc822Header:
            return self.buffer._writeString("RFC822.HEADER {\(size)}\r\n")
        }
    }
}
