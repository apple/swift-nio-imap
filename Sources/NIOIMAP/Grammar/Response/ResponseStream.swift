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

import NIO

extension NIOIMAP {
    
    /// You will recieve exactly one `greeting`
    /// For every `responseBegin`, there will be exactly one corresponding `responseEnd`
    /// For every `attributeBegin`, there will be exactly one corresponding `attributeEnd`
    /// For every `attributeBytes`, you may recieve 0...n `attributeBytes`
    /// For every `responseBegin`, you may recieve 0...m `simpleAttribute` and `attributeBegin`
    public enum ResponseStream: Equatable {
        case greeting(Greeting)
        case untaggedResponse(ResponseType)
        case attributesStart
        case simpleAttribute(MessageAttributeType)
        case streamingAttributeBegin(MessageAttributesStatic)
        case streamingAttributeBytes(ByteBuffer)
        case streamingAttributeEnd
        case attributesFinish
        case taggedResponse(ResponseTagged)
        case fatalResponse(ResponseText)
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult public mutating func writeResponseStream(_ response: NIOIMAP.ResponseStream) -> Int {
        switch response {
        case .greeting(let greeting):
            return self.writeGreeting(greeting)
        case .untaggedResponse(let resp):
            return self.writeResponseType(resp)
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
            return self.writeResponseTagged(end)
        case .fatalResponse(let fatal):
            return self.writeResponseFatal(fatal)
        }
    }
    
}
