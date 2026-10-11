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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("AttributeFlag")
struct AttributeFlagTests {
    /// An attribute flag is written verbatim inside `"/flags/…"`, so ``AttributeFlag/init(_:)`` is
    /// the only thing between a caller that builds flags from untrusted input and an injected
    /// command.
    @Test(
        "invalid flags are rejected",
        arguments: [
            "",  // `atom` is `1*ATOM-CHAR`.
            #"\\"#,  // `"\\" atom`, and the atom may not be empty.
            #"\seen"#,  // A lone backslash escapes the next byte of the quoted entry name.
            #"\\\seen"#,
            #"a\b"#,
            #"a"b"#,
            "a b",
            "a(b",
            "a]b",
            "grüezi",
            "a\u{7F}b",
            "x\" all 1\r\nA2 DELETE INBOX\r\nA3 NOOP \"",  // Would inject a whole command.
        ]
    )
    func invalidFlags(_ string: String) {
        #expect(AttributeFlag(string) == nil)
    }

    @Test("valid flags", arguments: validFlagStrings)
    func validFlags(_ string: String) {
        #expect(AttributeFlag(string).map { String($0) } == string.lowercased())
    }

    /// Written verbatim, so every flag we accept has to parse back unchanged.
    @Test("valid flags round-trip", arguments: validFlagStrings)
    func validFlagsRoundTrip(_ string: String) throws {
        ParseFixture.attributeFlag(string, expected: .success(try #require(AttributeFlag(string)))).checkParsing()
    }

    /// `entry-flag-name = DQUOTE "/flags/" attr-flag DQUOTE`: the stored form is already escaped.
    @Test("valid flags round-trip as entry flag names", arguments: validFlagStrings)
    func validFlagsRoundTripAsEntryFlagName(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            EntryFlagName(flag: try #require(AttributeFlag(string))),
            terminator: " ",
            encoder: { $0.writeEntryFlagName($1) },
            parser: GrammarParser().parseEntryFlagName
        )
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let flag: AttributeFlag = #"\seen"#
                _ = flag
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid attribute flag")
    }
    #endif

    @Test(
        "encode",
        arguments: [
            EncodeFixture.attributeFlag(.answered, "\\\\answered"),
            EncodeFixture.attributeFlag(.deleted, "\\\\deleted"),
            EncodeFixture.attributeFlag(.draft, "\\\\draft"),
            EncodeFixture.attributeFlag(.flagged, "\\\\flagged"),
            EncodeFixture.attributeFlag(.seen, "\\\\seen"),
            EncodeFixture.attributeFlag("test", "test"),
        ]
    )
    func encode(_ fixture: EncodeFixture<AttributeFlag>) {
        fixture.checkEncoding()
    }

    @Test("lowercased normalization")
    func lowercasedNormalization() {
        #expect(AttributeFlag("TEST") == AttributeFlag("test"))
        #expect(AttributeFlag("TEST").stringValue == "test")
        #expect(AttributeFlag("test").stringValue == "test")
    }

    @Test(
        "string conversion",
        arguments: [
            (AttributeFlag.answered, "\\\\answered"),
            (AttributeFlag("custom"), "custom"),
        ] as [(AttributeFlag, String)]
    )
    func stringConversion(_ fixture: (AttributeFlag, String)) {
        #expect(String(fixture.0) == fixture.1)
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.attributeFlag(#"\\Answered"#, expected: .success(.answered)),
            ParseFixture.attributeFlag("some", expected: .success("some")),
        ]
    )
    func parse(_ fixture: ParseFixture<AttributeFlag>) {
        fixture.checkParsing()
    }
}

// MARK: -

private let validFlagStrings = [
    #"\\Seen"#,
    #"\\answered"#,
    #"\\X-Vendor"#,
    "$Forwarded",
    "custom",
]

extension EncodeFixture<AttributeFlag> {
    fileprivate static func attributeFlag(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAttributeFlag($1) }
        )
    }
}

extension ParseFixture<AttributeFlag> {
    fileprivate static func attributeFlag(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAttributeFlag
        )
    }
}
