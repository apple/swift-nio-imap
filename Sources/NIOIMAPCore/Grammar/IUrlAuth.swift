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
public struct IURLAuth: Equatable {
    /// The URL.
    public var auth: IURLAuthRump

    /// The auth url verifier.
    public var verifier: IUAVerifier

    /// Creates a new `IURLAuth`.
    /// - parameter auth: The auth URL.
    /// - parameter verifier: The auth URL verifier.
    public init(auth: IURLAuthRump, verifier: IUAVerifier) {
        self.auth = auth
        self.verifier = verifier
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIURLAuth(_ data: IURLAuth) -> Int {
        self.writeIURLAuthRump(data.auth) +
            self.writeIUAVerifier(data.verifier)
    }
}
