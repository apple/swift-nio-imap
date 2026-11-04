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

@Suite("OptionExtensionKind.Vendor")
struct OptionVendorTagTests {
    /// A vendor tag is written verbatim, so ``OptionExtensionKind/Vendor/init(_:)`` is the only
    /// thing between a caller that builds tags from untrusted input and an injected command.
    @Test(
        "invalid vendor tags are rejected",
        arguments: [
            "",
            "ACME",  // No `-`.
            "-SORT",  // `vendor-token` may not be empty.
            "ACME-",  // `atom` may not be empty.
            "AC1-SORT",  // `vendor-token` is `1*ALPHA`.
            "ACME-a b",
            "ACME-a)b",
            "ACME-a]b",
            #"ACME-a"b"#,
            "ACME-GRÜEZI",
            "X-FOO)\r\nA2 DELETE INBOX\r\nA3 LIST (",  // Would inject a whole command.
        ]
    )
    func invalidVendorTags(_ string: String) {
        #expect(OptionExtensionKind.Vendor(string) == nil)
    }

    @Test(
        "token and name",
        arguments: [
            ("ACME-SORT", "ACME", "SORT"),
            ("X-FOO-BAR", "X", "FOO-BAR"),
        ]
    )
    func tokenAndName(_ string: String, _ token: String, _ name: String) throws {
        let tag = try #require(OptionExtensionKind.Vendor(string))
        #expect(String(tag) == string)
        #expect(tag.token == token)
        #expect(tag.name == name)
    }

    /// Written verbatim, so every tag we accept has to parse back unchanged.
    @Test("valid vendor tags round-trip", arguments: ["ACME-SORT", "X-FOO-BAR", "some-thing"])
    func validVendorTagsRoundTrip(_ string: String) throws {
        ParseFixture.optionVendorTag(string, expected: .success(try #require(OptionExtensionKind.Vendor(string))))
            .checkParsing()
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid vendor tag literal traps") func vendorTagLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let tag: OptionExtensionKind.Vendor = "ACME"
                _ = tag
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid option vendor tag")
    }
    #endif

    @Test(
        "encode",
        arguments: [
            EncodeFixture.optionVendorTag("some-thing", "some-thing")
        ]
    )
    func encode(_ fixture: EncodeFixture<OptionExtensionKind.Vendor>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.optionVendorTag("ACME-SORT", ")", expected: .success("ACME-SORT")),
            ParseFixture.optionVendorTag("FOO-BAR", ")", expected: .success("FOO-BAR")),
            ParseFixture.optionVendorTag("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<OptionExtensionKind.Vendor>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<OptionExtensionKind.Vendor> {
    fileprivate static func optionVendorTag(
        _ input: OptionExtensionKind.Vendor,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeOptionVendorTag($1) }
        )
    }
}

extension ParseFixture<OptionExtensionKind.Vendor> {
    fileprivate static func optionVendorTag(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseOptionVendorTag
        )
    }
}
