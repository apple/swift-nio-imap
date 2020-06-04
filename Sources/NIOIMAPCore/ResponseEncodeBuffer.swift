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

public struct ResponseEncodeBuffer {
    private var buffer: EncodeBuffer

    public var bytes: ByteBuffer {
        var encodeBuffer = self.buffer
        return encodeBuffer.nextChunk().bytes
    }

    public init(buffer: ByteBuffer, capabilities: EncodingCapabilities) {
        self.buffer = EncodeBuffer(buffer, mode: .client, capabilities: capabilities)
    }
}

// MARK: - Encode ContinueRequest

extension ResponseEncodeBuffer {
    @discardableResult public mutating func writeContinueRequest(_ data: ContinueRequest) -> Int {
        var size = 0
        size += self.buffer.writeString("+ ")
        switch data {
        case .responseText(let text):
            size += self.buffer.writeResponseText(text)
        case .base64(let base64):
            size += self.buffer.writeBase64(base64)
        }
        size += self.buffer.writeString("\r\n")
        return size
    }
}

// MARK: - Encode Response

extension ResponseEncodeBuffer {
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
            if case .server(streamingAttributes: true) = self.buffer.mode {
                return self.buffer.writeSpace() + self.buffer.writeMessageAttribute(att)
            } else {
                self.buffer.mode = .server(streamingAttributes: true)
                return self.buffer.writeMessageAttribute(att)
            }
        case .streamingBegin(let type, let size):
            if case .server(streamingAttributes: true) = self.buffer.mode {
                return self.buffer.writeSpace() + self.writeStreamingType(type, size: size)
            } else {
                self.buffer.mode = .server(streamingAttributes: true)
                return self.writeStreamingType(type, size: size)
            }
        case .streamingBytes(var bytes):
            return self.buffer.writeBuffer(&bytes)
        case .streamingEnd:
            return 0 // do nothing, this is a "fake" event
        case .finish:
            self.buffer.mode = .server(streamingAttributes: false)
            return self.buffer.writeString(")\r\n")
        }
    }

    @discardableResult mutating func writeStreamingType(_ type: StreamingType, size: Int) -> Int {
        switch type {
        case .binary:
            return self.buffer.writeString("BINARY {\(size)}\r\n")
        case .body:
            return self.buffer.writeString("BODY[TEXT] {\(size)}\r\n")
        case .rfc822:
            return self.buffer.writeString("RFC822.TEXT {\(size)}\r\n")
        }
    }
}
