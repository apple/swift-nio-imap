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
    /// For every `attributeBegin`, there will be exactly one corresponding `responseEnd`
    /// For every `attributeBegin`, you may recieve 0...n `attributeBytes`
    /// For every `responseBegin`, you may recieve 0...m `simpleAttribute` and `attributeBegin`
    public enum ResponseStream: Equatable {
        case greeting(Greeting)
        case responseBegin(ResponseData)
        case simpleAttribute(MessageAttributeType)
        case attributeBegin(MessageAttributesStatic)
        case attributeBytes(ByteBuffer)
        case attributeEnd
        case responseEnd(ResponseDone)
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult public mutating func writeResponseStream(_ response: NIOIMAP.ResponseStream) -> Int {
        switch response {
        case .greeting(let greeting):
            return self.writeGreeting(greeting)
        case .responseBegin(let resp):
            return self.writeResponseData(resp)
        case .simpleAttribute(let att):
            return self.writeMessageAttributeType(att)
        case .attributeBegin(let att):
            return self.writeMessageAttributeStatic(att)
        case .attributeBytes(var bytes):
            return self.writeBuffer(&bytes)
        case .attributeEnd:
            return 0 // do nothing, this is a "fake" event
        case .responseEnd(let end):
            return self.writeResponseDone(end)
        }
    }
    
}
