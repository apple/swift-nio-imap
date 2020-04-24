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
        case attributesStart
        case simpleAttribute(MessageAttributeType)
        case streamingAttributeBegin(MessageAttributesStatic)
        case streamingAttributeBytes(ByteBuffer)
        case streamingAttributeEnd
        case attributesFinish
        case taggedResponse(TaggedResponse)
        case fatalResponse(ResponseText)
        case continuationRequest(ContinueRequest)
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
        case .attributesStart:
            return self.writeString("(")
        case .simpleAttribute(let att):
            return self.writeMessageAttributeType(att)
        case .streamingAttributeBegin(let att):
            return self.writeMessageAttributeStatic(att)
        case .streamingAttributeBytes(var bytes):
            return self.writeBuffer(&bytes)
        case .streamingAttributeEnd:
            return 0 // do nothing, this is a "fake" event
        case .attributesFinish:
            return self.writeString(")")
        case .taggedResponse(let end):
            return self.writeTaggedResponse(end)
        case .fatalResponse(let fatal):
            return self.writeResponseFatal(fatal)
        case .continuationRequest(let req):
            return self.writeContinueRequest(req)
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
