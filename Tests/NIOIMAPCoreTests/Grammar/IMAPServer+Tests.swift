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

@Suite("IMAP Server")
struct IMAPServerTests {
    @Test(arguments: [
        EncodeFixture.imapServer(.init(host: "localhost"), "localhost"),
        EncodeFixture.imapServer(
            .init(
                userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                host: "localhost"
            ),
            ";AUTH=*@localhost"
        ),
        EncodeFixture.imapServer(.init(host: "localhost", port: 1234), "localhost:1234"),
        EncodeFixture.imapServer(
            .init(
                userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                host: "localhost",
                port: 1234
            ),
            ";AUTH=*@localhost:1234"
        ),
    ])
    func encode(_ fixture: EncodeFixture<IMAPServer>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.imapServer(
            "localhost",
            " ",
            expected: .success(.init(userAuthenticationMechanism: nil, host: "localhost", port: nil))
        ),
        ParseFixture.imapServer(
            ";AUTH=*@localhost",
            " ",
            expected: .success(
                .init(
                    userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                    host: "localhost",
                    port: nil
                )
            )
        ),
        ParseFixture.imapServer(
            "localhost:1234",
            " ",
            expected: .success(.init(userAuthenticationMechanism: nil, host: "localhost", port: 1234))
        ),
        ParseFixture.imapServer(
            ";AUTH=*@localhost:1234",
            " ",
            expected: .success(
                .init(
                    userAuthenticationMechanism: .init(encodedUser: nil, authenticationMechanism: .any),
                    host: "localhost",
                    port: 1234
                )
            )
        ),
        // An IP literal keeps its brackets.
        ParseFixture.imapServer(
            "[::1]:1234",
            " ",
            expected: .success(.init(userAuthenticationMechanism: nil, host: "[::1]", port: 1234))
        ),
        ParseFixture.imapServer(
            "192.0.2.1",
            " ",
            expected: .success(.init(userAuthenticationMechanism: nil, host: "192.0.2.1", port: nil))
        ),
        ParseFixture.imapServer(
            "a%c3%a9;x=y",
            " ",
            expected: .success(.init(userAuthenticationMechanism: nil, host: "a%C3%A9;x=y", port: nil))
        ),
        ParseFixture.imapServer("[someHost]", " ", expected: .failure),
        ParseFixture.imapServer("a%zz", " ", expected: .failure),
        ParseFixture.imapServer("localhost:65536", " ", expected: .failure),
    ])
    func parse(_ fixture: ParseFixture<IMAPServer>) {
        fixture.checkParsing()
    }

    /// A host is written to the wire verbatim, inside a URL that is itself written bare in
    /// `[REFERRAL …]`.
    @Test(
        "invalid hosts are rejected",
        arguments: [
            "h] x\r\n* BYE",  // Would inject a whole response.
            "a b",
            "a/b",
            "a@b",
            "a:1",
            "a]",
            "a%",
            "a%2g",
            "Grüezi",  // Must be percent-encoded.
            "[]",
            "[::1",
            "::1",
            "[someHost]",
            "[1:2:3:4:5:6:7:8:9]",
            "[1:2:3:4:5:6:7]",
            "[1:2:3:4:5:6:7:8::]",
            "[1::2::3]",
            "[:::]",
            "[:1:2:3:4:5:6:7]",
            "[12345::]",
            "[::g]",
            "[192.0.2.1::]",
            "[::256.0.2.1]",
            "[::01.0.2.1]",
            "[::1.2.3]",
            "[v1]",
            "[v.x]",
            "[vg.x]",
            "[w1.x]",
            "[v1.]",
            "[v1.a b]",
        ]
    )
    func invalidHosts(_ string: String) {
        #expect(IMAPServer.Host(string) == nil)
    }

    @Test("valid hosts", arguments: validHostStrings)
    func validHosts(_ string: String) {
        #expect(IMAPServer.Host(string).map { String($0) } == string)
    }

    @Test("pct-encoded hex digits are uppercased")
    func normalization() {
        #expect(IMAPServer.Host("a%c3%a9" as String).map { String($0) } == "a%C3%A9")
    }

    /// Covers N2: IP literals used to lose their brackets.
    @Test("valid hosts round-trip", arguments: validHostStrings)
    func validHostsRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            IMAPServer(host: try #require(IMAPServer.Host(string)), port: 143),
            encoder: { $0.writeIMAPServer($1) },
            parser: GrammarParser().parseIMAPServer
        )
    }

    /// RFC 3986 §3.2.2: hosts are case-insensitive. The stored case is kept for the wire.
    @Test(
        "compares case-insensitively, keeps case",
        arguments: [
            ("imap.example.com", "IMAP.Example.COM"),
            ("a%C3%A9", "A%c3%a9"),
            ("[2001:db8::a]", "[2001:DB8::A]"),
            ("[v1a.x]", "[V1A.X]"),
        ]
    )
    func caseInsensitive(_ lowerString: String, _ upperString: String) throws {
        let lower = try #require(IMAPServer.Host(lowerString))
        let upper = try #require(IMAPServer.Host(upperString))
        #expect(lower == upper)
        #expect(lower.hashValue == upper.hashValue)
        #expect(Set([lower, upper]).count == 1)
        #expect([lower: 1][upper] == 1)
        #expect(lower != "imap.example.net")
        #expect(String(lower) == lowerString)
    }

    /// `==` ignores case, so round-trip tests can't catch a parser that changes it.
    @Test("parsing keeps case", arguments: ["imap.example.com", "Imap.Example.COM", "[2001:db8::a]", "[v1a.x]"])
    func parseKeepsCase(_ string: String) throws {
        var buffer = ParseBuffer(ByteBuffer(string: string + " "))
        let parsed = try GrammarParser().parseHost(buffer: &buffer, tracker: .testTracker)
        #expect(String(parsed) == string)
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent],
            performing: {
                let host: IMAPServer.Host = "a b"
                _ = host
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid host")
    }
    #endif
}

// MARK: -

private let validHostStrings = [
    "",  // `reg-name = *( … )`.
    "localhost",
    "imap.example.com",
    "a%C3%A9",
    "AZaz09-._~!$&'()*+,;=",
    "192.0.2.1",
    "999.1.1.1",  // Not an IPv4address, but a reg-name.
    "[::]",
    "[::1]",
    "[1::]",
    "[2001:db8::1]",
    "[2001:DB8:0:0:8:800:200C:417A]",
    "[1:2:3:4:5:6:7::]",
    "[1:2:3:4:5:6::7]",
    "[::ffff:192.0.2.1]",
    "[1:2:3:4:5:6:192.0.2.1]",
    "[::192.0.2.1]",
    "[v1.a:b!]",
    "[VF.x]",
]

extension EncodeFixture<IMAPServer> {
    fileprivate static func imapServer(
        _ input: IMAPServer,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIMAPServer($1) }
        )
    }
}

extension ParseFixture<IMAPServer> {
    fileprivate static func imapServer(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIMAPServer
        )
    }
}
