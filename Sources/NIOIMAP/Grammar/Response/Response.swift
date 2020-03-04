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
    
    /// IMAPv4 `response`
    public struct Response: Equatable {
        public var parts: [ResponseType]
        public var done: ResponseDone
        
        public static func parts(_ parts: [ResponseType], done: ResponseDone) -> Self {
            return Self(parts: parts, done: done)
        }
    }
    
    public enum ResponseType: Equatable {
        case continueRequest(ContinueRequest)
        case responseData(ResponseData)
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeResponseType(_ type: NIOIMAP.ResponseType) -> Int {
        switch type {
        case .continueRequest(let continueRequest):
            return self.writeContinueRequest(continueRequest)
        case .responseData(let data):
            return self.writeResponseData(data)
        }
    }

    @discardableResult mutating func writeResponse(_ response: NIOIMAP.Response) -> Int {
        response.parts.reduce(0) { (result, part) in
            result + self.writeResponseType(part)
        } +
        self.writeResponseDone(response.done)
    }

}
