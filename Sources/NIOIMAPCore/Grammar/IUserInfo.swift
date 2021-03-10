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

/// Matches an encoded user with a permitted authentication mechanism.
public struct IUserInfo: Equatable {
    /// The percent-encoded user data.
    public var encodedUser: EncodedUser?

    /// The authentication mechanism.
    public var authenticationMechanism: IAuthentication?

    /// Creates a new `IUserInfo`.
    /// - parameter encodedUser: The percent-encoded user data.
    /// - parameter authenticationMechanism: The authentication mechanism.
    public init(encodedUser: EncodedUser?, authenticationMechanism: IAuthentication?) {
        precondition(encodedUser != nil || authenticationMechanism != nil, "Need one of `encodedUser` or `iAuth`")
        self.encodedUser = encodedUser
        self.authenticationMechanism = authenticationMechanism
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIUserInfo(_ data: IUserInfo) -> Int {
        self.writeIfExists(data.encodedUser) { user in
            self.writeEncodedUser(user)
        } +
            self.writeIfExists(data.authenticationMechanism) { iAuth in
                self.writeIAuthentication(iAuth)
            }
    }
}
