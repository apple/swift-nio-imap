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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("AuthenticatedURLVerifier")
struct AuthenticatedURLVerifierTests {
    @Test(arguments: [
        EncodeFixture.authenticatedURLVerifier(
            .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "test")),
            ":INTERNAL:test"
        ),
        EncodeFixture.authenticatedURLVerifier(
            .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "verifier123")),
            ":INTERNAL:verifier123"
        ),
    ])
    func encode(_ fixture: EncodeFixture<AuthenticatedURLVerifier>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<AuthenticatedURLVerifier> {
    fileprivate static func authenticatedURLVerifier(
        _ input: AuthenticatedURLVerifier,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAuthenticatedURLVerifier($1) }
        )
    }
}
