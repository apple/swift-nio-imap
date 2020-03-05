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
        case greeting(Greeting)
        case bytes(ByteBuffer)
        case body(ResponseType)
        case end(ResponseDone)
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
        case .body(let type):
            return self.writeResponseType(type)
        case .end(let end):
            return self.writeResponseDone(end)
        }
    }
    
}
