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

    public enum ServerResponse: Equatable {
        case greeting(Greeting)
        case response(Response)
    }
        
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult public mutating func writeServerResponse(_ response: NIOIMAP.ServerResponse) -> Int {
        switch response {
        case .greeting(let greeting):
            return self.writeGreeting(greeting)
        case .response(let response):
            return self.writeResponse(response)
        }
    }

}
