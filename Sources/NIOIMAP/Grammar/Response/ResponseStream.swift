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

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult public mutating func writeResponseStream(_ response: NIOIMAP.ResponseStream) -> Int {
        switch response {
        case .greeting(let greeting):
            return self.writeGreeting(greeting)
        case .responseBegin(let resp):
            return self.writeResponseData(resp)
        case .attributesStart:
            return self.writeString("(")
        case .simpleAttribute(let att):
            return self.writeMessageAttributeType(att)
        case .streamingAttributeBegin(let att):
            return self.writeMessageAttributeStatic(att)
        case .streamingAttributeBytes(let bytes):
            return self.writeBytes(bytes)
        case .streamingAttributeEnd:
            return 0 // do nothing, this is a "fake" event
        case .attributesFinish:
            return self.writeString(")")
        case .responseEnd(let end):
            return self.writeResponseDone(end)
        }
    }
    
}
