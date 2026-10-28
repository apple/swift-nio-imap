//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

@Suite("AuthenticationMechanism")
struct AuthenticationMechanismTests {
    @Test("uppercased normalization")
    func uppercasedNormalization() {
        #expect(AuthenticationMechanism("plain") == .plain)
        #expect(AuthenticationMechanism("plain").map { String($0) } == "PLAIN")
        #expect(AuthenticationMechanism("Scram-Sha-256").map { String($0) } == "SCRAM-SHA-256")
    }

    /// Mechanism names are not restricted to letters: digits, `-` and `_` are allowed, too.
    @Test(
        "valid names",
        arguments: [
            "PLAIN",
            "GSSAPI",
            "EXTERNAL",
            "XOAUTH2",
            "SCRAM-SHA-256",
            "SCRAM-SHA-256-PLUS",
            "CRAM-MD5",
            "DIGEST-MD5",
            "X_SOMETHING",
            "A",
            "OAUTH10A-FOR-A-LONG-",  // The maximum of 20 characters.
        ]
    )
    func validNames(_ name: String) {
        #expect(AuthenticationMechanism(name).map { String($0) } == name)
    }

    @Test(
        "invalid names are rejected",
        arguments: [
            "",
            "PL.AIN",
            "PLAIN:",
            "PLAIN AND MORE",
            "SCRAM+SHA+256",
            "MECHANISM/NAME",
            "GRÜEZI",
            "🤦",
            "PLAIN\u{00}",
            "OAUTH10A-FOR-A-LONGER",  // 21 characters, one over the maximum.
        ]
    )
    func invalidNames(_ name: String) {
        #expect(AuthenticationMechanism(name) == nil)
    }

    @Test(
        "encode",
        arguments: [
            EncodeFixture.authenticationMechanism(.gssAPI, "GSSAPI"),
            EncodeFixture.authenticationMechanism(.plain, "PLAIN"),
            EncodeFixture.authenticationMechanism(.init("myAuth")!, "MYAUTH"),
            EncodeFixture.authenticationMechanism(.init("xoauth2")!, "XOAUTH2"),
        ]
    )
    func encode(_ fixture: EncodeFixture<AuthenticationMechanism>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.authenticationMechanism("PLAIN", expected: .success(.plain)),
            ParseFixture.authenticationMechanism("GSSAPI", expected: .success(.gssAPI)),
            ParseFixture.authenticationMechanism("SCRAM-SHA-256", expected: .success(.init("SCRAM-SHA-256")!)),
            // A lowercase name is out of spec, but is normalized rather than rejected.
            ParseFixture.authenticationMechanism("plain", expected: .success(.plain)),
        ]
    )
    func parse(_ fixture: ParseFixture<AuthenticationMechanism>) {
        fixture.checkParsing()
    }

    /// A name that the specification doesn’t allow is a parse error, so that a command which
    /// couldn’t be encoded again can never be created by parsing.
    @Test(
        "parsing rejects invalid names",
        arguments: [
            "PL.AIN",
            "OAUTH10A-FOR-A-LONGER",
        ]
    )
    func parseInvalidNames(_ name: String) {
        ParseFixture.authenticationMechanism(name, expected: .failureIgnoringBufferModifications)
            .checkParsing()
    }
}

// MARK: -

extension EncodeFixture<AuthenticationMechanism> {
    fileprivate static func authenticationMechanism(
        _ input: AuthenticationMechanism,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAuthenticationMechanism($1) }
        )
    }
}

extension ParseFixture<AuthenticationMechanism> {
    fileprivate static func authenticationMechanism(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthenticationMechanism
        )
    }
}
