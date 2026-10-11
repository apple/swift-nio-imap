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

/// `EncodedUser`, `EncodedAuthenticationType` (`1*achar`) and `EncodedMailbox`, `EncodedSearch`,
/// `EncodedSection` (`1*bchar`) are written verbatim inside a URL that is itself written bare,
/// e.g. in `[REFERRAL …]`. `init?(_:)` is all that stands between untrusted input and an injected
/// response.
@Suite("Encoded URL components")
struct EncodedURLComponentTests {
    @Test("invalid achar components are rejected", arguments: invalidBcharStrings + [":", "@", "/"])
    func invalidAchar(_ string: String) {
        #expect(EncodedUser(string) == nil)
        #expect(EncodedAuthenticationType(string) == nil)
    }

    /// `;AUTH=*` means any mechanism, so `*` can't be a mechanism name.
    @Test("* is not an authentication type")
    func asteriskAuthenticationType() {
        #expect(EncodedAuthenticationType("*" as String) == nil)
        #expect(EncodedAuthenticationType("**" as String) != nil)
    }

    @Test(
        "URL authentication mechanisms round-trip",
        arguments: [IMAPURLAuthenticationMechanism.any, .type("**"), .type("*x")]
    )
    func authenticationMechanismRoundTrip(_ mechanism: IMAPURLAuthenticationMechanism) {
        TestUtilities.expectRoundTrip(
            mechanism,
            encoder: { $0.writeIMAPURLAuthenticationMechanism($1) },
            parser: GrammarParser().parseIMAPURLAuthenticationMechanism
        )
    }

    @Test("invalid bchar components are rejected", arguments: invalidBcharStrings)
    func invalidBchar(_ string: String) {
        #expect(EncodedMailbox(string) == nil)
        #expect(EncodedSearch(string) == nil)
        #expect(EncodedSection(string) == nil)
    }

    @Test("valid achar components", arguments: validAcharStrings)
    func validAchar(_ string: String) {
        #expect(EncodedUser(string).map { String($0) } == string)
        #expect(EncodedAuthenticationType(string).map { String($0) } == string)
    }

    @Test("valid bchar components", arguments: validBcharStrings)
    func validBchar(_ string: String) {
        #expect(EncodedMailbox(string).map { String($0) } == string)
        #expect(EncodedSearch(string).map { String($0) } == string)
        #expect(EncodedSection(string).map { String($0) } == string)
    }

    /// The parser uppercases them, so values must too, to round-trip.
    @Test("pct-encoded hex digits are uppercased")
    func normalization() {
        #expect(EncodedUser("Fr%c3%a9d" as String).map { String($0) } == "Fr%C3%A9d")
        #expect(EncodedAuthenticationType("a%2d" as String).map { String($0) } == "a%2D")
        #expect(EncodedMailbox("a%ff/b" as String).map { String($0) } == "a%FF/b")
        #expect(EncodedSearch("a%ff" as String).map { String($0) } == "a%FF")
        #expect(EncodedSection("a%ff" as String).map { String($0) } == "a%FF")
        let literal: EncodedMailbox = "a%ff"
        #expect(String(literal) == "a%FF")
    }

    @Test("achar components round-trip", arguments: validAcharStrings + ["a%ff"])
    func acharRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            try #require(EncodedUser(string)),
            encoder: { $0.writeEncodedUser($1) },
            parser: GrammarParser().parseEncodedUser
        )
        TestUtilities.expectRoundTrip(
            try #require(EncodedAuthenticationType(string)),
            encoder: { $0.writeEncodedAuthenticationType($1) },
            parser: GrammarParser().parseEncodedAuthenticationType
        )
    }

    @Test("bchar components round-trip", arguments: validBcharStrings + ["a%ff"])
    func bcharRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            try #require(EncodedMailbox(string)),
            encoder: { $0.writeEncodedMailbox($1) },
            parser: GrammarParser().parseEncodedMailbox
        )
        TestUtilities.expectRoundTrip(
            try #require(EncodedSearch(string)),
            encoder: { $0.writeEncodedSearch($1) },
            parser: GrammarParser().parseEncodedSearch
        )
        TestUtilities.expectRoundTrip(
            try #require(EncodedSection(string)),
            encoder: { $0.writeEncodedSection($1) },
            parser: GrammarParser().parseEncodedSection
        )
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid EncodedUser literal traps") func encodedUserLiteral() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let value: EncodedUser = "a/b"
                _ = value
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid encoded user")
    }

    @Test("an invalid EncodedAuthenticationType literal traps") func encodedAuthenticationTypeLiteral() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let value: EncodedAuthenticationType = "a b"
                _ = value
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid encoded authentication type")
    }

    @Test("an invalid EncodedMailbox literal traps") func encodedMailboxLiteral() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let value: EncodedMailbox = "a b"
                _ = value
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid encoded mailbox")
    }

    @Test("an invalid EncodedSearch literal traps") func encodedSearchLiteral() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let value: EncodedSearch = "a b"
                _ = value
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid encoded search")
    }

    @Test("an invalid EncodedSection literal traps") func encodedSectionLiteral() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let value: EncodedSection = "a b"
                _ = value
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid encoded section")
    }
    #endif
}

// MARK: -

private let invalidBcharStrings = [
    "",  // `1*bchar`.
    "a b",
    "a]b",  // Would end `[REFERRAL …]`.
    #"a"b"#,
    #"a\b"#,
    "a[b",
    "a;b",
    "a?b",
    "a#b",
    "a<b",
    "a\u{7F}b",
    "Grüezi",  // Must be percent-encoded.
    "%",  // `pct-encoded = "%" HEXDIG HEXDIG`.
    "a%",
    "a%2",
    "a%zz",
    "a%2g",
    "%%41",
    "x\r\n* BYE",  // Would inject a whole response.
]

private let validAcharStrings = [
    "a",
    "Fr%C3%A9d%C3%A9ric",
    "%00",
    "AZaz09-._~",
    "!$'()*+,&=",
]

private let validBcharStrings =
    validAcharStrings + [
        "foo/bar",
        "a:b@c",
        "/",
    ]
