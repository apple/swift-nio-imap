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

/// RFC 5092
public struct IUAVerifier: Equatable {
    public var uAuthMechanism: UAuthMechanism
    public var encodedURLAuth: EncodedURLAuth

    public init(uAuthMechanism: UAuthMechanism, encodedURLAuth: EncodedURLAuth) {
        self.uAuthMechanism = uAuthMechanism
        self.encodedURLAuth = encodedURLAuth
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUAVerifier(_ data: IUAVerifier) -> Int {
        self.writeString(":") +
            self.writeUAuthMechanism(data.uAuthMechanism) +
            self.writeString(":") +
            self.writeEncodedURLAuth(data.encodedURLAuth)
    }
}
