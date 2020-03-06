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
    
    public enum ResponseStream: Equatable {
        case bytes(ByteBuffer)
        case greeting(Greeting)
        case response(ResponseComponentStream)
    }
    
    public enum ResponseComponentStream: Equatable {
        case body(ResponseBodyStream)
        case end(ResponseDone)
    }
    
    public enum ResponseBodyStream: Equatable {
        case whole(ResponseType)
        case messageAttribute(MessageAttributeType)
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult public mutating func writeResponseStream(_ stream: NIOIMAP.ResponseStream) -> Int {
        switch stream {
        case .bytes(let buffer):
            var copy = buffer
            return self.writeBuffer(&copy)
        case .greeting(let greeting):
            return self.writeGreeting(greeting)
        case .response(let component):
            return self.writeResponseComponentStream(component)
        }
    }
    
    @discardableResult mutating func writeResponseComponentStream(_ stream: NIOIMAP.ResponseComponentStream) -> Int {
        switch stream {
        case .body(let body):
            return self.writeResponseBodyStream(body)
        case .end(let done):
            return self.writeResponseDone(done)
        }
    }
    
    @discardableResult mutating func writeResponseBodyStream(_ stream: NIOIMAP.ResponseBodyStream) -> Int {
        switch stream {
        case .messageAttribute(let att):
            return self.writeMessageAttributeType(att)
        case .whole(let type):
            return self.writeResponseType(type)
        }
    }
    
}
