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
    private var buffer: EncodeBuffer

    /// Data that is waiting to be sent.
    public var bytes: ByteBuffer {
        var encodeBuffer = self.buffer
        return encodeBuffer.nextChunk().bytes
    }

    /// Creates a new `ResponseEncodeBuffer` from an initial `ByteBuffer` and configuration.
    /// - parameter buffer: The inital `ByteBuffer` to use. Note that this is copied, not taken as `inout`.
    /// - parameter options: The `ResponseEncodingOptions` to use when writing responses.
    public init(buffer: ByteBuffer, options: ResponseEncodingOptions) {
        self.buffer = .serverEncodeBuffer(buffer: buffer, options: options)
    }
}

extension ResponseEncodeBuffer {
    /// Creates a new `ResponseEncodeBuffer` from an initial `ByteBuffer` and configuration.
    /// - parameter buffer: The inital `ByteBuffer` to use. Note that this is copied, not taken as `inout`.
    /// - parameter capabilities: Server capabilites to use when writing responses. These will be converted into a `ResponseEncodingOptions`.
    public init(buffer: ByteBuffer, capabilities: [Capability]) {
        self.buffer = .serverEncodeBuffer(buffer: buffer, capabilities: capabilities)
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
        case .untaggedResponse(let resp):
            return self.buffer.writeResponseData(resp)
        case .fetchResponse(let response):
            return self.writeFetchResponse(response)
        case .taggedResponse(let end):
            return self.buffer.writeTaggedResponse(end)
        case .fatalResponse(let fatal):
            return self.buffer.writeResponseFatal(fatal)
        }
    }

    @discardableResult mutating func writeFetchResponse(_ response: FetchResponse) -> Int {
        switch response {
        case .start(let num):
            return self.buffer.writeString("* \(num) FETCH (")
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
                if let size = size {
                    return self.buffer.writeSpace() + self.writeStreamingKind(type, size: size)
                } else {
                    fatalError("We shouldn't ever reach this, we should always write as literal instead of quoted.")
                }
            } else {
                self.buffer.mode = .server(streamingAttributes: true, options: options)
                if let size = size {
                    return self.writeStreamingKind(type, size: size)
                } else {
                    fatalError("We shouldn't ever reach this, we should always write as literal instead of quoted.")
                }
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

    @discardableResult mutating func writeStreamingKind(_ type: StreamingKind, size: Int) -> Int {
        switch type {
        case .binary:
            return self.buffer.writeString("BINARY {\(size)}\r\n")
        case .body(let section, let offset):
            return self.buffer.writeString("BODY") +
                self.buffer.writeSection(section) +
                self.buffer.writeIfExists(offset) { offset in
                    self.buffer.writeString("<\(offset)>")
                } + self.buffer.writeString("{\(size)}\r\n")
        case .rfc822:
            return self.buffer.writeString("RFC822 {\(size)}\r\n")
        case .rfc822Text:
            return self.buffer.writeString("RFC822.TEXT {\(size)}\r\n")
        case .rfc822Header:
            return self.buffer.writeString("RFC822.HEADER {\(size)}\r\n")
        }
    }
}
