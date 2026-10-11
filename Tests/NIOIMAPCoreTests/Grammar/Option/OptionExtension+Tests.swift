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

@Suite("OptionExtension KeyValue")
struct OptionExtensionTests {
    /// A standard tag is written verbatim, so ``OptionExtensionKind/Standard/init(_:)`` is the only
    /// thing between a caller that builds tags from untrusted input and an injected command.
    @Test(
        "invalid standard tags are rejected",
        arguments: [
            "",  // `atom` is `1*ATOM-CHAR`.
            "a b",
            "a(b",
            "a)b",
            "a]b",
            #"a"b"#,
            #"a\b"#,
            "GRÜEZI",
            "a\u{7F}b",
            "X)\r\nA2 DELETE INBOX\r\nA3 LIST (",  // Would inject a whole command.
        ]
    )
    func invalidStandardTags(_ string: String) {
        #expect(OptionExtensionKind.Standard(string) == nil)
    }

    /// Written verbatim, so every tag we accept has to parse back unchanged.
    @Test("valid standard tags round-trip", arguments: ["REMOTE", "MYEXT", "ACME-SORT", "X.1"])
    func validStandardTagsRoundTrip(_ string: String) throws {
        let tag = try #require(OptionExtensionKind.Standard(string))
        #expect(String(tag) == string)
        ParseFixture.optionExtension(string, expected: .success(.init(key: .standard(tag), value: nil)))
            .checkParsing()
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid standard tag literal traps") func standardTagLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let tag: OptionExtensionKind.Standard = "not an atom"
                _ = tag
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid option tag")
    }
    #endif

    @Test(arguments: [
        EncodeFixture.optionExtension(
            .init(key: .standard("test"), value: .string("string")),
            "test (\"string\")"
        ),
        EncodeFixture.optionExtension(
            .init(key: .vendor("token-atom"), value: nil),
            "token-atom"
        ),
        EncodeFixture.optionExtension(
            .init(key: .vendor("token-atom"), value: .string("value")),
            "token-atom (\"value\")"
        ),
    ])
    func encode(_ fixture: EncodeFixture<KeyValue<OptionExtensionKind, OptionValueComp?>>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.optionExtension(
            "MYEXT",
            ")",
            expected: .success(.init(key: .standard("MYEXT"), value: nil))
        ),
        ParseFixture.optionExtension(
            "MYEXT (\"val\")",
            ")",
            expected: .success(.init(key: .standard("MYEXT"), value: .string("val")))
        ),
        ParseFixture.optionExtension(
            "ACME-SORT",
            ")",
            expected: .success(.init(key: .standard("ACME-SORT"), value: nil))
        ),
        ParseFixture.optionExtension("", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<KeyValue<OptionExtensionKind, OptionValueComp?>>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<KeyValue<OptionExtensionKind, OptionValueComp?>> {
    fileprivate static func optionExtension(
        _ input: KeyValue<OptionExtensionKind, OptionValueComp?>,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeOptionExtension($1) }
        )
    }
}

extension ParseFixture<KeyValue<OptionExtensionKind, OptionValueComp?>> {
    fileprivate static func optionExtension(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseOptionExtension
        )
    }
}
