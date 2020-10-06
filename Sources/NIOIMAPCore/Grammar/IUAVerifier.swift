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
    public var encodedUrlAuth: EncodedUrlAuth
    
    public init(uAuthMechanism: UAuthMechanism, encodedUrlAuth: EncodedUrlAuth) {
        self.uAuthMechanism = uAuthMechanism
        self.encodedUrlAuth = encodedUrlAuth
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUAVerifier(_ data: IUAVerifier) -> Int {
        self.writeString(":") +
            self.writeUAuthMechanism(data.uAuthMechanism) +
            self.writeString(":") +
            self.writeEncodedUrlAuth(data.encodedUrlAuth)
    }
}
