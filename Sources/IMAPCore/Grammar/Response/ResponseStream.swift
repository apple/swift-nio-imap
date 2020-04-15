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



extension IMAPCore {
    
    /// You will recieve exactly one `greeting`
    /// For every `responseBegin`, there will be exactly one corresponding `responseEnd`
    /// For every `attributeBegin`, there will be exactly one corresponding `attributeEnd`
    /// For every `attributeBytes`, you may recieve 0...n `attributeBytes`
    /// For every `responseBegin`, you may recieve 0...m `simpleAttribute` and `attributeBegin`
    public enum ResponseStream: Equatable {
        case greeting(Greeting)
        case responseBegin(ResponsePayload)
        case attributesStart
        case simpleAttribute(MessageAttributeType)
        case streamingAttributeBegin(MessageAttributesStatic)
        case streamingAttributeBytes([UInt8])
        case streamingAttributeEnd
        case attributesFinish
        case responseEnd(ResponseDone)
    }
    
}
