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

    /// IMAPv4 `greeting`
    public enum Greeting: Equatable {
        case auth(ResponseConditionalAuth)
        case bye(ResponseText)
    }
}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeGreeting(_ greeting: IMAPCore.Greeting) -> Int {
        var size = 0
        size += self.writeString("* ")
        switch greeting {
        case .auth(let auth):
            size += self.writeResponseConditionalAuth(auth)
        case .bye(let bye):
            size += self.writeResponseConditionalBye(bye)
        }
        size += self.writeString("\r\n")
        return size
    }

}
