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

@Suite("URLAuthenticationMechanism")
struct URLAuthenticationMechanismTests {
    /// A mechanism is written to the wire verbatim, so ``URLAuthenticationMechanism/init(_:)`` is
    /// the only thing between a caller that builds mechanisms from untrusted input and an injected
    /// command.
    @Test(
        "invalid mechanisms are rejected",
        arguments: [
            "",  // `1*(ALPHA / DIGIT / "-" / ".")`.
            "a b",
            "a_b",
            "a+b",
            "a=b",
            "a(b",
            #"a"b"#,
            "GRÜEZI",  // ASCII only.
            "a\u{7F}b",
            "X\r\nA2 DELETE INBOX",  // Would inject a whole command.
        ]
    )
    func invalidMechanisms(_ string: String) {
        #expect(URLAuthenticationMechanism(string) == nil)
    }

    @Test("valid mechanisms", arguments: validMechanismStrings)
    func validMechanisms(_ string: String) {
        #expect(URLAuthenticationMechanism(string).map { String($0) } == string)
    }

    /// Written verbatim, so every mechanism we accept has to parse back unchanged.
    @Test("valid mechanisms round-trip", arguments: validMechanismStrings)
    func validMechanismsRoundTrip(_ string: String) throws {
        ParseFixture.urlAuthenticationMechanism(
            string,
            " ",
            expected: .success(try #require(URLAuthenticationMechanism(string)))
        ).checkParsing()
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let mechanism: URLAuthenticationMechanism = "not a mechanism"
                _ = mechanism
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid URLAUTH mechanism")
    }
    #endif

    @Test(arguments: [
        EncodeFixture.urlAuthenticationMechanism(
            .internal,
            "INTERNAL"
        ),
        EncodeFixture.urlAuthenticationMechanism(
            "test",
            "test"
        ),
    ])
    func encode(_ fixture: EncodeFixture<URLAuthenticationMechanism>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.urlAuthenticationMechanism(
            "INTERNAL",
            " ",
            expected: .success(.internal)
        ),
        ParseFixture.urlAuthenticationMechanism(
            "abcdEFG0123456789",
            " ",
            expected: .success("abcdEFG0123456789")
        ),
    ])
    func parse(_ fixture: ParseFixture<URLAuthenticationMechanism>) {
        fixture.checkParsing()
    }

    @Test(
        "string conversion",
        arguments: [
            (URLAuthenticationMechanism.internal, "INTERNAL"),
            (URLAuthenticationMechanism("CUSTOM"), "CUSTOM"),
        ] as [(URLAuthenticationMechanism, String)]
    )
    func stringConversion(_ fixture: (URLAuthenticationMechanism, String)) {
        #expect(String(fixture.0) == fixture.1)
    }
}

// MARK: -

private let validMechanismStrings = [
    "INTERNAL",
    "test",
    "abcdEFG0123456789",
    "X-VENDOR.1",
]

extension EncodeFixture<URLAuthenticationMechanism> {
    fileprivate static func urlAuthenticationMechanism(
        _ input: URLAuthenticationMechanism,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLAuthenticationMechanism($1) }
        )
    }
}

extension ParseFixture<URLAuthenticationMechanism> {
    fileprivate static func urlAuthenticationMechanism(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUAuthMechanism
        )
    }
}
