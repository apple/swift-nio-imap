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

/// Used to verify IMAP URL authorization.
public struct AuthenticatedURLVerifier: Hashable {
    /// The auth mechanism.
    public var urlAuthenticationMechanism: URLAuthenticationMechanism

    /// The percent-encoded authentication data.
    public var encodedAuthenticationURL: EncodedAuthenticatedURL

    /// Creates a new `AuthenticatedURLVerifier`.
    /// - parameter urlAuthMechanism: The auth mechanism.
    /// - parameter encodedAuthenticationURL: The percent-encoded authentication data.
    public init(urlAuthMechanism: URLAuthenticationMechanism, encodedAuthenticationURL: EncodedAuthenticatedURL) {
        self.urlAuthenticationMechanism = urlAuthMechanism
        self.encodedAuthenticationURL = encodedAuthenticationURL
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticatedURLVerifier(_ data: AuthenticatedURLVerifier) -> Int {
        self.writeString(":") +
            self.writeURLAuthenticationMechanism(data.urlAuthenticationMechanism) +
            self.writeString(":") +
            self.writeEncodedAuthenticationURL(data.encodedAuthenticationURL)
    }
}
