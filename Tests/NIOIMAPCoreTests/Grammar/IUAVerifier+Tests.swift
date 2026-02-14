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

    @Test(arguments: [
        ParseFixture.authenticatedURLVerifier(
            ":INTERNAL:01234567890123456789012345678901",
            " ",
            expected: .success(.init(
                urlAuthMechanism: .internal,
                encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
            ))
        ),
    ])
    func parse(_ fixture: ParseFixture<AuthenticatedURLVerifier>) {
        fixture.checkParsing()
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

extension ParseFixture<AuthenticatedURLVerifier> {
    fileprivate static func authenticatedURLVerifier(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthenticatedURLVerifier
        )
    }
}
