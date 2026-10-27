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

@Suite("Envelope")
struct EnvelopeTests {
    @Test(arguments: [
        EncodeFixture.envelope(
            Envelope(
                date: "01-02-03",
                subject: nil,
                from: [],
                sender: [],
                reply: [],
                to: [],
                cc: [],
                bcc: [],
                inReplyTo: nil,
                messageID: "1"
            ),
            "(\"01-02-03\" NIL NIL NIL NIL NIL NIL NIL NIL \"1\")"
        ),
        EncodeFixture.envelope(
            Envelope(
                date: "01-02-03",
                subject: "subject",
                from: [
                    .singleAddress(
                        .init(personName: "name1", sourceRoot: "adl1", mailbox: "mailbox1", host: "host1")
                    )
                ],
                sender: [
                    .singleAddress(
                        .init(personName: "name2", sourceRoot: "adl2", mailbox: "mailbox2", host: "host2")
                    )
                ],
                reply: [
                    .singleAddress(
                        .init(personName: "name3", sourceRoot: "adl3", mailbox: "mailbox3", host: "host3")
                    )
                ],
                to: [
                    .singleAddress(
                        .init(personName: "name4", sourceRoot: "adl4", mailbox: "mailbox4", host: "host4")
                    )
                ],
                cc: [
                    .singleAddress(
                        .init(personName: "name5", sourceRoot: "adl5", mailbox: "mailbox5", host: "host5")
                    )
                ],
                bcc: [
                    .singleAddress(
                        .init(personName: "name6", sourceRoot: "adl6", mailbox: "mailbox6", host: "host6")
                    )
                ],
                inReplyTo: nil,
                messageID: "1"
            ),
            "(\"01-02-03\" \"subject\" ((\"name1\" \"adl1\" \"mailbox1\" \"host1\")) ((\"name2\" \"adl2\" \"mailbox2\" \"host2\")) ((\"name3\" \"adl3\" \"mailbox3\" \"host3\")) ((\"name4\" \"adl4\" \"mailbox4\" \"host4\")) ((\"name5\" \"adl5\" \"mailbox5\" \"host5\")) ((\"name6\" \"adl6\" \"mailbox6\" \"host6\")) NIL \"1\")"
        ),
    ])
    func encode(_ fixture: EncodeFixture<Envelope>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse envelope",
        arguments: [
            // Envelope where env-to is `()` instead of `NIL`.
            ParseFixture.envelope(
                #"("Wed, 11 Oct 2023 03:11:07 +0000" "some subject" (("Tn" NIL "info" "e.example.com")) NIL NIL () NIL NIL "<426119111385110898173554@bar.example.com>" "<foo@example.com>")"#,
                expected: .success(
                    Envelope(
                        date: "Wed, 11 Oct 2023 03:11:07 +0000",
                        subject: "some subject",
                        from: [
                            .singleAddress(
                                .init(personName: "Tn", sourceRoot: nil, mailbox: "info", host: "e.example.com")
                            )
                        ],
                        sender: [],
                        reply: [],
                        to: [],
                        cc: [],
                        bcc: [],
                        inReplyTo: "<426119111385110898173554@bar.example.com>",
                        messageID: "<foo@example.com>"
                    )
                )
            ),
            ParseFixture.envelope(
                #"("date" "subject" (("name1" "adl1" "mailbox1" "host1")) (("name2" "adl2" "mailbox2" "host2")) (("name3" "adl3" "mailbox3" "host3")) (("name4" "adl4" "mailbox4" "host4") ("name5" "adl5" "mailbox5" "host5")) (("name6" "adl6" "mailbox6" "host6")("name7" "adl7" "mailbox7" "host7")) (("name8" "adl8" "mailbox8" "host8")) "someone" "messageid")"#,
                expected: .success(
                    Envelope(
                        date: "date",
                        subject: "subject",
                        from: [
                            .singleAddress(
                                .init(personName: "name1", sourceRoot: "adl1", mailbox: "mailbox1", host: "host1")
                            )
                        ],
                        sender: [
                            .singleAddress(
                                .init(personName: "name2", sourceRoot: "adl2", mailbox: "mailbox2", host: "host2")
                            )
                        ],
                        reply: [
                            .singleAddress(
                                .init(personName: "name3", sourceRoot: "adl3", mailbox: "mailbox3", host: "host3")
                            )
                        ],
                        to: [
                            .singleAddress(
                                .init(personName: "name4", sourceRoot: "adl4", mailbox: "mailbox4", host: "host4")
                            ),
                            .singleAddress(
                                .init(personName: "name5", sourceRoot: "adl5", mailbox: "mailbox5", host: "host5")
                            ),
                        ],
                        cc: [
                            .singleAddress(
                                .init(personName: "name6", sourceRoot: "adl6", mailbox: "mailbox6", host: "host6")
                            ),
                            .singleAddress(
                                .init(personName: "name7", sourceRoot: "adl7", mailbox: "mailbox7", host: "host7")
                            ),
                        ],
                        bcc: [
                            .singleAddress(
                                .init(personName: "name8", sourceRoot: "adl8", mailbox: "mailbox8", host: "host8")
                            )
                        ],
                        inReplyTo: "someone",
                        messageID: "messageid"
                    )
                )
            ),
            // Malformed From (unclosed group, stray end), well-formed To group.
            ParseFixture.envelope(
                #"("date" "subject" ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL)(NIL NIL NIL NIL)) NIL NIL ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL)) NIL NIL NIL NIL)"#,
                expected: .success(
                    Envelope(
                        date: "date",
                        subject: "subject",
                        from: [.group(.init(groupName: "Team", sourceRoot: nil, children: [.alice]))],
                        sender: [],
                        reply: [],
                        to: [.group(.init(groupName: "Team", sourceRoot: nil, children: [.alice]))],
                        cc: [],
                        bcc: [],
                        inReplyTo: nil,
                        messageID: nil
                    )
                )
            ),
            ParseFixture.envelope(
                #"("date" "subject" ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")) NIL NIL ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL)) NIL NIL NIL NIL)"#,
                expected: .success(
                    Envelope(
                        date: "date",
                        subject: "subject",
                        from: [.singleAddress(.groupStart("Team")), .singleAddress(.alice)],
                        sender: [],
                        reply: [],
                        to: [.group(.init(groupName: "Team", sourceRoot: nil, children: [.alice]))],
                        cc: [],
                        bcc: [],
                        inReplyTo: nil,
                        messageID: nil
                    )
                )
            ),
        ]
    )
    func parseEnvelope(_ fixture: ParseFixture<Envelope>) {
        fixture.checkParsing()
    }

    @Test(
        "parse envelope email addresses",
        arguments: [
            ParseFixture.envelopeEmailAddresses(
                "((NIL NIL NIL NIL))",
                " ",
                expected: .success([.init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil)])
            ),
            ParseFixture.envelopeEmailAddresses(
                #"(("a" "b" "c" "d"))"#,
                " ",
                expected: .success([.init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d")])
            ),
            ParseFixture.envelopeEmailAddresses("NIL", " ", expected: .failure),
        ]
    )
    func parseEnvelopeEmailAddresses(_ fixture: ParseFixture<[EmailAddress]>) {
        fixture.checkParsing()
    }

    @Test(
        "parse optional envelope email addresses",
        arguments: [
            ParseFixture.optionalEnvelopeEmailAddresses(
                #"(("a" "b" "c" "d"))"#,
                " ",
                expected: .success([.singleAddress(.init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d"))])
            ),
            ParseFixture.optionalEnvelopeEmailAddresses("NIL", " ", expected: .success([])),
            ParseFixture.optionalEnvelopeEmailAddresses("()", " ", expected: .success([])),
            // Malformed group markers (#859): normalized, never thrown.
            ParseFixture.optionalEnvelopeEmailAddresses("((NIL NIL NIL NIL))", " ", expected: .success([])),
            ParseFixture.optionalEnvelopeEmailAddresses(
                "((NIL NIL NIL NIL)(NIL NIL NIL NIL))",
                " ",
                expected: .success([])
            ),
            // Cyrus 07: `To: alice@example.com;`
            ParseFixture.optionalEnvelopeEmailAddresses(
                #"((NIL NIL "alice" "example.com")(NIL NIL NIL NIL))"#,
                " ",
                expected: .success([.singleAddress(.alice)])
            ),
            ParseFixture.optionalEnvelopeEmailAddresses(
                #"((NIL NIL NIL NIL)(NIL NIL "alice" "example.com"))"#,
                " ",
                expected: .success([.singleAddress(.alice)])
            ),
            // Unclosed group: start demoted to a host-NIL address.
            ParseFixture.optionalEnvelopeEmailAddresses(
                #"((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com"))"#,
                " ",
                expected: .success([.singleAddress(.groupStart("Team")), .singleAddress(.alice)])
            ),
            // Nested start: outer demoted, inner kept.
            ParseFixture.optionalEnvelopeEmailAddresses(
                #"((NIL NIL "A" NIL)(NIL NIL "B" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL))"#,
                " ",
                expected: .success([
                    .singleAddress(.groupStart("A")),
                    .group(.init(groupName: "B", sourceRoot: nil, children: [.alice])),
                ])
            ),
            // Malicious server: unqualified addresses.
            ParseFixture.optionalEnvelopeEmailAddresses(
                #"((NIL NIL "root" NIL)(NIL NIL "root" NIL))"#,
                " ",
                expected: .success([.singleAddress(.groupStart("root")), .singleAddress(.groupStart("root"))])
            ),
        ]
    )
    func parseOptionalEnvelopeEmailAddresses(_ fixture: ParseFixture<[EmailAddressListElement]>) {
        fixture.checkParsing()
    }

    /// `parse(encode(parse(x))) == parse(x)`. A list of only end markers folds to `[]`, which encodes as `NIL`.
    @Test(
        "envelope addresses round trip",
        arguments: [
            AddressListRoundTripFixture(input: "((NIL NIL NIL NIL))", expectedEncoding: "NIL"),
            AddressListRoundTripFixture(
                input: #"((NIL NIL "alice" "example.com")(NIL NIL NIL NIL))"#,
                expectedEncoding: #"((NIL NIL "alice" "example.com"))"#
            ),
            AddressListRoundTripFixture(input: #"((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com"))"#),
            AddressListRoundTripFixture(
                input: #"((NIL NIL "A" NIL)(NIL NIL "B" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL))"#
            ),
            AddressListRoundTripFixture(input: #"((NIL NIL "root" NIL)(NIL NIL "root" NIL))"#),
            AddressListRoundTripFixture(
                input: #"((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL))"#,
                expectedEncoding: #"((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL))"#
            ),
        ]
    )
    func envelopeAddressesRoundTrip(_ fixture: AddressListRoundTripFixture) throws {
        let parsed = try Self.parseAddressList(fixture.input)
        let encoded = Self.encodeAddressList(parsed)
        if let expectedEncoding = fixture.expectedEncoding {
            #expect(encoded == expectedEncoding)
        }
        #expect(try Self.parseAddressList(encoded) == parsed)
    }

    private static func parseAddressList(_ string: String) throws -> [EmailAddressListElement] {
        // Trailing space: the list must not be at the end of the buffer.
        var buffer = ParseBuffer(ByteBuffer(string: string + " "))
        return try GrammarParser().parseOptionalEnvelopeEmailAddresses(buffer: &buffer, tracker: .testTracker)
    }

    private static func encodeAddressList(_ addresses: [EmailAddressListElement]) -> String {
        var buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        buffer.writeEnvelopeAddresses(addresses)
        var result = ""
        while true {
            let chunk = buffer.nextChunk()
            result += String(buffer: chunk.bytes)
            guard chunk.waitForContinuation else { return result }
        }
    }
}

// MARK: -

struct AddressListRoundTripFixture: Sendable, CustomTestStringConvertible {
    var input: String
    /// `nil`: encoding not pinned.
    var expectedEncoding: String? = nil

    var testDescription: String { input }
}

extension EmailAddress {
    fileprivate static let alice = EmailAddress(personName: nil, sourceRoot: nil, mailbox: "alice", host: "example.com")

    /// RFC 3501 §7.4.2 group start marker (host NIL).
    fileprivate static func groupStart(_ name: ByteBuffer) -> EmailAddress {
        .init(personName: nil, sourceRoot: nil, mailbox: name, host: nil)
    }
}

extension EncodeFixture<Envelope> {
    fileprivate static func envelope(
        _ input: Envelope,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEnvelope($1) }
        )
    }
}

extension ParseFixture<Envelope> {
    fileprivate static func envelope(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEnvelope
        )
    }
}

extension ParseFixture<[EmailAddress]> {
    fileprivate static func envelopeEmailAddresses(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEnvelopeEmailAddresses
        )
    }
}

extension ParseFixture<[EmailAddressListElement]> {
    fileprivate static func optionalEnvelopeEmailAddresses(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseOptionalEnvelopeEmailAddresses
        )
    }
}
