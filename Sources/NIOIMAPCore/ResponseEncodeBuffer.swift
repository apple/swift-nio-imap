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
public struct ResponseEncodeBuffer: Sendable {
    private var buffer: EncodeBuffer

    /// Data that is waiting to be sent.
    public mutating func readBytes() -> ByteBuffer {
        let buffer = self.buffer.nextChunk().bytes
        precondition(self.buffer.buffer.readableBytes == 0)
        self.buffer.buffer.clear()
        return buffer
    }

    /// Creates a new `ResponseEncodeBuffer` from an initial `ByteBuffer` and configuration.
    /// - parameter buffer: The inital `ByteBuffer` to use. Note that this is copied, not taken as `inout`.
    /// - parameter options: The `ResponseEncodingOptions` to use when writing responses.
    public init(buffer: ByteBuffer, options: ResponseEncodingOptions, loggingMode: Bool) {
        self.buffer = .serverEncodeBuffer(buffer: buffer, options: options, loggingMode: loggingMode)
    }
}

extension ResponseEncodeBuffer {
    /// Creates a new `ResponseEncodeBuffer` from an initial `ByteBuffer` and configuration.
    /// - parameter buffer: The inital `ByteBuffer` to use. Note that this is copied, not taken as `inout`.
    /// - parameter capabilities: Server capabilites to use when writing responses. These will be converted into a `ResponseEncodingOptions`.
    public init(buffer: ByteBuffer, capabilities: [Capability], loggingMode: Bool) {
        self.buffer = .serverEncodeBuffer(buffer: buffer, capabilities: capabilities, loggingMode: loggingMode)
    }
}

extension ResponseEncodeBuffer {
    /// Call the closure with a buffer, return the result as a String.
    ///
    /// Used for implementing ``CustomDebugStringConvertible`` conformance.
    static func makeDescription(loggingMode: Bool, _ closure: (inout ResponseEncodeBuffer) -> Void) -> String {
        var options = ResponseEncodingOptions()
        options.useQuotedString = true
        var buffer = ResponseEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: loggingMode)
        closure(&buffer)
        return String(bestEffortDecodingUTF8Bytes: buffer.buffer.buffer.readableBytesView)
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
        return self.buffer.writeString("+ ") +
            self.buffer.writeBytes(base64) +
            self.buffer.writeString("\r\n")
    }

    @discardableResult mutating func writeFetchResponse(_ response: FetchResponse) -> Int {
        switch response {
        case .start(let num):
            return self.buffer.writeString("* ") +
                self.buffer.writeSequenceNumber(num) +
                self.buffer.writeString(" FETCH (")
        case .startUID(let num):
            return self.buffer.writeString("* ") +
                self.buffer.writeMessageIdentifier(num) +
                self.buffer.writeString(" UIDFETCH (")
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
            return self.buffer.writeBuffer(&bytes)
        case .streamingEnd:
            return 0 // do nothing, this is a "fake" event
        case .finish:
            guard case .server(_, let options) = self.buffer.mode else {
                preconditionFailure("Only server can write responses.")
            }
            self.buffer.mode = .server(streamingAttributes: false, options: options)
            return self.buffer.writeString(")\r\n")
        }
    }

    @discardableResult mutating func writeStreamingKind(_ kind: StreamingKind, size: Int) -> Int {
        self.buffer.writeStreamingKind(kind) +
            self.buffer.writeSpace() +
            self.buffer.writeString("{\(size)}\r\n")
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeStreamingKind(_ kind: StreamingKind) -> Int {
        switch kind {
        case .binary:
            return self.writeString("BINARY")
        case .body(let section, let offset):
            return self.writeString("BODY") +
                self.writeSection(section) +
                self.writeIfExists(offset) { offset in
                    self.writeString("<\(offset)>")
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
