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

@Suite("QuotaResource.Name")
struct QuotaResourceNameTests {
    /// A name is written to the wire verbatim, so ``QuotaResource/Name/init(_:)`` is the only thing
    /// between a caller that builds names from untrusted input and an injected response.
    @Test(
        "invalid names are rejected",
        arguments: [
            "",  // `atom` is `1*ATOM-CHAR`.
            "a b",
            "a(b",
            "a)b",
            "a{b",
            #"a"b"#,
            #"a\b"#,
            "a%b",
            "a*b",
            "a]b",  // `resource-name-ext` is `atom`, which excludes resp-specials.
            "GRÜEZI",  // `ATOM-CHAR` is ASCII.
            "a\u{7F}b",  // CTL.
            "a\u{01}b",  // CTL.
            "STORAGE\r\n* 1 EXPUNGE\r\n",  // Would inject an untagged response.
        ]
    )
    func invalidNames(_ name: String) {
        #expect(QuotaResource.Name(name) == nil)
    }

    @Test("valid names", arguments: validNameStrings)
    func validNames(_ name: String) {
        #expect(QuotaResource.Name(name).map { String($0) } == name)
    }

    /// A name is written verbatim, so every name we accept has to parse back unchanged.
    @Test("valid names round-trip", arguments: validNameStrings)
    func validNamesRoundTrip(_ name: String) throws {
        ParseFixture.quotaResourceName(name, expected: .success(try #require(QuotaResource.Name(name))))
            .checkParsing()
    }

    @Test(
        "registered names",
        arguments: [
            (QuotaResource.Name.storage, "STORAGE"),
            (QuotaResource.Name.message, "MESSAGE"),
            (QuotaResource.Name.mailbox, "MAILBOX"),
            (QuotaResource.Name.annotationStorage, "ANNOTATION-STORAGE"),
        ] as [(QuotaResource.Name, String)]
    )
    func registeredNames(_ fixture: (QuotaResource.Name, String)) {
        #expect(String(fixture.0) == fixture.1)
    }

    /// RFC 9208 §7: "Except as noted otherwise, all alphabetic characters are case insensitive."
    @Test("equality is case-insensitive, encoding is case-preserving")
    func caseHandling() {
        let lowercase: QuotaResource.Name = "storage"
        expectEqualAndEqualHash(lowercase, .storage)
        expectEqualAndEqualHash("Storage" as QuotaResource.Name, .storage)
        #expect(lowercase != .message)
        #expect(String(lowercase) == "storage")
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        await #expect(
            processExitsWith: ExitTest.Condition.failure,
            performing: {
                let name: QuotaResource.Name = "not an atom"
                _ = name
            }
        )
    }
    #endif
}

// MARK: -

private let validNameStrings = [
    "STORAGE",
    "MESSAGE",
    "MAILBOX",
    "ANNOTATION-STORAGE",
    "X-VENDOR",
]

extension ParseFixture<QuotaResource.Name> {
    fileprivate static func quotaResourceName(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseQuotaResourceName
        )
    }
}
