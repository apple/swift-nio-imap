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

/// Specifies a URL and a verifier that can be used to verify the authorisation URL.
public struct IAuthenticatedURL: Equatable {
    /// The URL.
    public var authenticatedURL: IRumpAuthenticatedURL

    /// The auth url verifier.
    public var verifier: AuthenticatedURLVerifier

    /// Creates a new `IURLAuth`.
    /// - parameter authenticatedURL: The auth URL.
    /// - parameter verifier: The auth URL verifier.
    public init(authenticatedURL: IRumpAuthenticatedURL, verifier: AuthenticatedURLVerifier) {
        self.authenticatedURL = authenticatedURL
        self.verifier = verifier
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIAuthenticatedURL(_ data: IAuthenticatedURL) -> Int {
        self.writeIRumpAuthenticatedURL(data.authenticatedURL) +
            self.writeAuthenticatedURLVerifier(data.verifier)
    }
}
