//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// The method to use when authenticating a user.
public struct AuthenticationKind: Hashable {
    /// Use a token generated by a specified algorithm.
    public static let token = Self(unchecked: "TOKEN")

    /// Combines the username and password into one base64 string.
    public static let plain = Self(unchecked: "PLAIN")

    /// Use a PToken.
    public static let pToken = Self(unchecked: "PTOKEN")

    /// Use a WEToken.
    public static let weToken = Self(unchecked: "WETOKEN")

    /// Use a WSToken.
    public static let wsToken = Self(unchecked: "WSTOKEN")

    /// Use the GSSAPI protocol.
    public static let gssAPI = Self(unchecked: "GSSAPI")

    /// The name of the authentication method.
    public var rawValue: String

    /// Creates a new `AuthenticationKind`.
    /// - parameter value: The name of the authentication method. Will be uppercased.
    public init(_ value: String) {
        self.rawValue = value.uppercased()
    }

    fileprivate init(unchecked: String) {
        self.rawValue = unchecked
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticationKind(_ kind: AuthenticationKind) -> Int {
        self.writeString(kind.rawValue)
    }
}
