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

    @Test("parse envelope", arguments: [
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
        )
    ])
    func parseEnvelope(_ fixture: ParseFixture<Envelope>) {
        fixture.checkParsing()
    }

    @Test("parse envelope email addresses", arguments: [
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
    ])
    func parseEnvelopeEmailAddresses(_ fixture: ParseFixture<[EmailAddress]>) {
        fixture.checkParsing()
    }

    @Test("parse optional envelope email addresses", arguments: [
        ParseFixture.optionalEnvelopeEmailAddresses(
            #"(("a" "b" "c" "d"))"#,
            " ",
            expected: .success([.singleAddress(.init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d"))])
        ),
        ParseFixture.optionalEnvelopeEmailAddresses("NIL", " ", expected: .success([])),
    ])
    func parseOptionalEnvelopeEmailAddresses(_ fixture: ParseFixture<[EmailAddressListElement]>) {
        fixture.checkParsing()
    }
}

// MARK: -

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
