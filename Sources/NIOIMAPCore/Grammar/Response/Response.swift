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
import struct NIO.ByteBufferAllocator

public enum ResponseOrContinueRequest: Equatable {
    case continueRequest(ContinueRequest)
    case response(Response)
}

public enum Response: Equatable {
    case untaggedResponse(ResponsePayload)
    case fetchResponse(FetchResponse)
    case taggedResponse(TaggedResponse)
    case fatalResponse(ResponseText)
}

/// The first event will always be `start`
/// The last event will always be `finish`
/// Every `start` has exactly one corresponding `finish`
/// After recieving `start` you may recieve n `simpleAttribute`, `streamingBegin`, and `streamingBytes` events.
/// Every `streamingBegin` has exaclty one corresponding `streamingEnd`
/// `streamingBegin` has a `type` that specifies the type of data to be streamed
public enum FetchResponse: Equatable {
    case start(Int)
    case simpleAttribute(MessageAttribute)
    case streamingBegin(type: StreamingType, byteCount: Int)
    case streamingBytes(ByteBuffer)
    case streamingEnd
    case finish
}

public enum StreamingType: Equatable {
    case binary(section: SectionSpecifier.Part) /// BINARY RFC 3516, streams BINARY when using a `literal`
    case body(partial: Int?) /// IMAP4rev1 RFC 3501, streams BODY[TEXT] when using a `literal`
    case rfc822 /// IMAP4rev1 RFC 3501, streams RF822.TEXT when using a `literal`
}

// MARK: - Encoding

extension ResponseEncodeBuffer {
    @discardableResult public mutating func writeResponse(_ response: Response) -> Int {
        switch response {
        case .untaggedResponse(let resp):
            return self._buffer.writeResponseData(resp)
        case .fetchResponse(let response):
            return self.writeFetchResponse(response)
        case .taggedResponse(let end):
            return self._buffer.writeTaggedResponse(end)
        case .fatalResponse(let fatal):
            return self._buffer.writeResponseFatal(fatal)
        }
    }

    @discardableResult mutating func writeFetchResponse(_ response: FetchResponse) -> Int {
        switch response {
        case .start(let num):
            return self._buffer.writeString("* \(num) FETCH (")
        case .simpleAttribute(let att):
            if case .server(streamingAttributes: true) = self._buffer.mode {
                return self._buffer.writeSpace() + self._buffer.writeMessageAttribute(att)
            } else {
                self._buffer.mode = .server(streamingAttributes: true)
                return self._buffer.writeMessageAttribute(att)
            }
        case .streamingBegin(let type, let size):
            if case .server(streamingAttributes: true) = self._buffer.mode {
                return self._buffer.writeSpace() + self.writeStreamingType(type, size: size)
            } else {
                self._buffer.mode = .server(streamingAttributes: true)
                return self.writeStreamingType(type, size: size)
            }
        case .streamingBytes(var bytes):
            return self._buffer.writeBuffer(&bytes)
        case .streamingEnd:
            return 0 // do nothing, this is a "fake" event
        case .finish:
            self._buffer.mode = .server(streamingAttributes: false)
            return self._buffer.writeString(")\r\n")
        }
    }

    @discardableResult mutating func writeStreamingType(_ type: StreamingType, size: Int) -> Int {
        switch type {
        case .binary:
            return self._buffer.writeString("BINARY {\(size)}\r\n")
        case .body:
            return self._buffer.writeString("BODY[TEXT] {\(size)}\r\n")
        case .rfc822:
            return self._buffer.writeString("RFC822.TEXT {\(size)}\r\n")
        }
    }
}
