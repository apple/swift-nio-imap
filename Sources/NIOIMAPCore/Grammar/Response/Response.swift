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

extension NIOIMAP {
    public enum Response: Equatable {
        case greeting(Greeting)
        case untaggedResponse(ResponsePayload)
        case fetchResponse(FetchResponse)
        case taggedResponse(TaggedResponse)
        case fatalResponse(ResponseText)
        case continuationRequest(ContinueRequest)
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
        case binary(section: [Int]) /// BINARY RFC 3516, streams BINARY when using a `literal`
        case body(partial: Int?) /// IMAP4rev1 RFC 3501, streams BODY[TEXT] when using a `literal`
        case rfc822 /// IMAP4rev1 RFC 3501, streams RF822.TEXT when using a `literal`
    }

    public enum ResponseType: Equatable {
        case continueRequest(ContinueRequest)
        case responseData(ResponsePayload)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult public mutating func writeResponse(_ response: NIOIMAP.Response) -> Int {
        switch response {
        case .greeting(let greeting):
            return self.writeGreeting(greeting)
        case .untaggedResponse(let resp):
            return self.writeResponseData(resp)
        case .fetchResponse(let response):
            return self.writeFetchResponse(response)
        case .taggedResponse(let end):
            return self.writeTaggedResponse(end)
        case .fatalResponse(let fatal):
            return self.writeResponseFatal(fatal)
        case .continuationRequest(let req):
            return self.writeContinueRequest(req)
        }
    }

    @discardableResult mutating func writeFetchResponse(_ response: NIOIMAP.FetchResponse) -> Int {
        switch response {
        case .start:
            return self.writeString("(")
        case .simpleAttribute(let att):
            return self.writeMessageAttribute(att)
        case .streamingBegin(let type, let size):
            return self.writeStreamingType(type, size: size)
        case .streamingBytes(var bytes):
            return self.writeBuffer(&bytes)
        case .streamingEnd:
            return 0 // do nothing, this is a "fake" event
        case .finish:
            return self.writeString(")")
        }
    }

    @discardableResult mutating func writeStreamingType(_ type: NIOIMAP.StreamingType, size: Int) -> Int {
        switch type {
        case .binary:
            return self.writeString("BINARY {\(size)}\r\n")
        case .body:
            return self.writeString("BODY[TEXT] {\(size)}\r\n")
        case .rfc822:
            return self.writeString("RFC822.TEXT {\(size)}\r\n")
        }
    }

    @discardableResult mutating func writeResponseType(_ type: NIOIMAP.ResponseType) -> Int {
        switch type {
        case .continueRequest(let continueRequest):
            return self.writeContinueRequest(continueRequest)
        case .responseData(let data):
            return self.writeResponseData(data)
        }
    }
}
