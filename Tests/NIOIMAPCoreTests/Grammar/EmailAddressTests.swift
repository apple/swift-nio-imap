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

@Suite("EmailAddress")
struct EmailAddressTestsSuite {
    @Test("address initialization with properties")
    func addressInitializationWithProperties() {
        let name: ByteBuffer? = "a"
        let adl: ByteBuffer? = "b"
        let mailbox: ByteBuffer? = "c"
        let host: ByteBuffer? = "d"
        let address = EmailAddress(personName: name, sourceRoot: adl, mailbox: mailbox, host: host)

        #expect(address.personName == name)
        #expect(address.sourceRoot == adl)
        #expect(address.mailbox == mailbox)
        #expect(address.host == host)
    }

    @Test(
        "encode email address",
        arguments: [
            EmailAddressFixture(
                name: "all nil",
                address: .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                expectedString: "(NIL NIL NIL NIL)"
            ),
            EmailAddressFixture(
                name: "none nil",
                address: .init(
                    personName: "somename",
                    sourceRoot: "someadl",
                    mailbox: "somemailbox",
                    host: "someaddress"
                ),
                expectedString: "(\"somename\" \"someadl\" \"somemailbox\" \"someaddress\")"
            ),
            EmailAddressFixture(
                name: "mixed nil",
                address: .init(personName: nil, sourceRoot: "some", mailbox: "thing", host: nil),
                expectedString: "(NIL \"some\" \"thing\" NIL)"
            ),
            EmailAddressFixture(
                name: "unicode",
                address: .init(personName: nil, sourceRoot: nil, mailbox: "阿Q", host: "例子.中国"),
                expectedString: "(NIL NIL {4}\r\n阿Q {13}\r\n例子.中国)"
            ),
        ]
    )
    func encodeEmailAddress(_ fixture: EmailAddressFixture) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.emailAddress(
            "(NIL NIL NIL NIL)",
            "",
            expected: .success(.init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil))
        ),
        ParseFixture.emailAddress(
            #"("a" "b" "c" "d")"#,
            "",
            expected: .success(.init(personName: "a", sourceRoot: "b", mailbox: "c", host: "d"))
        ),
        ParseFixture.emailAddress(
            #"("å" "é" "ı" "ø")"#,
            "",
            expected: .success(.init(personName: "å", sourceRoot: "é", mailbox: "ı", host: "ø"))
        ),
        ParseFixture.emailAddress("(NIL NIL NIL NIL ", "\r", expected: .failure),
        ParseFixture.emailAddress("", "", expected: .incompleteMessage),
        ParseFixture.emailAddress("(NIL ", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<EmailAddress>) {
        fixture.checkParsing()
    }

    @Test(
        "parse envelope email address groups",
        arguments: [
            EnvelopeGroupingFixture(
                addresses: [],
                expected: []
            ),
            EnvelopeGroupingFixture(
                addresses: [.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")],
                expected: [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"))]
            ),
            EnvelopeGroupingFixture(
                addresses: [
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                ],
                expected: [
                    .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                    .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")),
                ]
            ),
            EnvelopeGroupingFixture(
                addresses: [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                expected: [
                    .group(
                        .init(
                            groupName: "group",
                            sourceRoot: nil,
                            children: [.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")]
                        )
                    )
                ]
            ),
            EnvelopeGroupingFixture(
                addresses: [
                    .init(personName: nil, sourceRoot: nil, mailbox: "group", host: nil),
                    .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                    .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                    .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                    .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                ],
                expected: [
                    .group(
                        .init(
                            groupName: "group",
                            sourceRoot: nil,
                            children: [
                                .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                                .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                                .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                            ]
                        )
                    )
                ]
            ),
            // Nested starts: only the innermost bracketed group survives; outer starts are demoted.
            EnvelopeGroupingFixture(
                name: "nested starts",
                addresses: [
                    .groupStart("group1"), .address("a"),
                    .groupStart("group2"), .address("b"),
                    .groupStart("group3"), .address("c"),
                    .groupEnd(), .groupEnd(), .groupEnd(),
                ],
                expected: [
                    .singleAddress(.groupStart("group1")),
                    .singleAddress(.address("a")),
                    .singleAddress(.groupStart("group2")),
                    .singleAddress(.address("b")),
                    .group(.init(groupName: "group3", sourceRoot: nil, children: [.address("c")])),
                ]
            ),
            // Issue #859 case 2: unclosed group is demoted, not lost.
            EnvelopeGroupingFixture(
                name: "unclosed group",
                addresses: [.groupStart("Team"), .address("alice")],
                expected: [.singleAddress(.groupStart("Team")), .singleAddress(.address("alice"))]
            ),
            // Issue #859 case 3 (Cyrus 07): stray end carries no data.
            EnvelopeGroupingFixture(
                name: "trailing stray end",
                addresses: [.address("alice"), .groupEnd()],
                expected: [.singleAddress(.address("alice"))]
            ),
            EnvelopeGroupingFixture(
                name: "leading stray end",
                addresses: [.groupEnd(), .address("alice")],
                expected: [.singleAddress(.address("alice"))]
            ),
            EnvelopeGroupingFixture(
                name: "double end after group",
                addresses: [.groupStart("Team"), .address("alice"), .groupEnd(), .groupEnd()],
                expected: [
                    .group(.init(groupName: "Team", sourceRoot: nil, children: [.address("alice")]))
                ]
            ),
            EnvelopeGroupingFixture(
                name: "lone end",
                addresses: [.groupEnd()],
                expected: []
            ),
            EnvelopeGroupingFixture(
                name: "only ends",
                addresses: [.groupEnd(), .groupEnd(), .groupEnd()],
                expected: []
            ),
            // Malicious server: unqualified addresses look like starts.
            EnvelopeGroupingFixture(
                name: "host-NIL addresses",
                addresses: [.groupStart("root"), .groupStart("admin")],
                expected: [.singleAddress(.groupStart("root")), .singleAddress(.groupStart("admin"))]
            ),
            // `undisclosed-recipients:;`
            EnvelopeGroupingFixture(
                name: "empty group",
                addresses: [.groupStart("undisclosed-recipients"), .groupEnd()],
                expected: [.group(.init(groupName: "undisclosed-recipients", sourceRoot: nil, children: []))]
            ),
            EnvelopeGroupingFixture(
                name: "start while open with members",
                addresses: [.groupStart("A"), .address("x"), .groupStart("B"), .address("y"), .groupEnd()],
                expected: [
                    .singleAddress(.groupStart("A")),
                    .singleAddress(.address("x")),
                    .group(.init(groupName: "B", sourceRoot: nil, children: [.address("y")])),
                ]
            ),
            // `To: : alice@example.com;` (Dovecot/Cyrus 20).
            EnvelopeGroupingFixture(
                name: "empty group name",
                addresses: [.groupStart(""), .address("alice"), .groupEnd()],
                expected: [.group(.init(groupName: "", sourceRoot: nil, children: [.address("alice")]))]
            ),
            EnvelopeGroupingFixture(
                name: "host set, mailbox NIL",
                addresses: [.init(personName: nil, sourceRoot: nil, mailbox: nil, host: "example.com")],
                expected: [.singleAddress(.init(personName: nil, sourceRoot: nil, mailbox: nil, host: "example.com"))]
            ),
            EnvelopeGroupingFixture(
                name: "empty host",
                addresses: [.init(personName: nil, sourceRoot: nil, mailbox: "Team", host: "")],
                expected: [.singleAddress(.init(personName: nil, sourceRoot: nil, mailbox: "Team", host: ""))]
            ),
            EnvelopeGroupingFixture(
                name: "bracketed start with source root",
                addresses: [.groupStart("Team", sourceRoot: "@relay"), .address("alice"), .groupEnd()],
                expected: [
                    .group(
                        .init(groupName: "Team", sourceRoot: "@relay", children: [.address("alice")])
                    )
                ]
            ),
            EnvelopeGroupingFixture(
                name: "demoted start with source root",
                addresses: [.groupStart("Team", sourceRoot: "@relay"), .address("alice")],
                expected: [
                    .singleAddress(.groupStart("Team", sourceRoot: "@relay")),
                    .singleAddress(.address("alice")),
                ]
            ),
            EnvelopeGroupingFixture(
                name: "demoted start with person name",
                addresses: [.groupStart("Team", personName: "T"), .address("alice")],
                expected: [
                    .singleAddress(.groupStart("Team", personName: "T")),
                    .singleAddress(.address("alice")),
                ]
            ),
            // Existing loss, kept: end marker fields are dropped.
            EnvelopeGroupingFixture(
                name: "end marker with person name and source root",
                addresses: [.groupStart("Team"), .address("alice"), .groupEnd(personName: "E", sourceRoot: "@relay")],
                expected: [
                    .group(.init(groupName: "Team", sourceRoot: nil, children: [.address("alice")]))
                ]
            ),
            // Existing loss, kept: bracketed start's person name is dropped.
            EnvelopeGroupingFixture(
                name: "bracketed start with person name",
                addresses: [.groupStart("Team", personName: "T"), .address("alice"), .groupEnd()],
                expected: [
                    .group(.init(groupName: "Team", sourceRoot: nil, children: [.address("alice")]))
                ]
            ),
        ]
    )
    func parseEnvelopeEmailAddressGroups(_ fixture: EnvelopeGroupingFixture) {
        let actual = GrammarParser().parseEnvelopeEmailAddressGroups(fixture.addresses)
        #expect(actual == fixture.expected)
    }
}

// MARK: -

struct EmailAddressFixture: Sendable, CustomTestStringConvertible {
    var name: String
    var address: EmailAddress
    var expectedString: String

    var testDescription: String { name }

    func checkEncoding() {
        let buffer = EncodeBuffer.serverEncodeBuffer(
            buffer: ByteBufferAllocator().buffer(capacity: 128),
            options: ResponseEncodingOptions(),
            loggingMode: false
        )
        var testBuffer = buffer
        let size = testBuffer.writeEmailAddress(address)
        var remaining = testBuffer
        let chunk = remaining.nextChunk()
        let actualString = String(buffer: chunk.bytes)

        #expect(size == expectedString.utf8.count)
        #expect(actualString.mappingControlPictures() == expectedString.mappingControlPictures())
    }
}

struct EnvelopeGroupingFixture: Sendable, CustomTestStringConvertible {
    var name: String? = nil
    var addresses: [EmailAddress]
    var expected: [EmailAddressListElement]

    var testDescription: String {
        name ?? "grouping \(addresses.count) addresses into \(expected.count) elements"
    }
}

// RFC 3501 §7.4.2 group markers: host NIL; start has mailbox = group name, end has mailbox NIL.
extension EmailAddress {
    fileprivate static func groupStart(
        _ name: ByteBuffer,
        personName: ByteBuffer? = nil,
        sourceRoot: ByteBuffer? = nil
    ) -> EmailAddress {
        .init(personName: personName, sourceRoot: sourceRoot, mailbox: name, host: nil)
    }

    fileprivate static func groupEnd(personName: ByteBuffer? = nil, sourceRoot: ByteBuffer? = nil) -> EmailAddress {
        .init(personName: personName, sourceRoot: sourceRoot, mailbox: nil, host: nil)
    }

    /// Ordinary address with every field set to `value`.
    fileprivate static func address(_ value: ByteBuffer) -> EmailAddress {
        .init(personName: value, sourceRoot: value, mailbox: value, host: value)
    }
}

extension ParseFixture<EmailAddress> {
    fileprivate static func emailAddress(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEmailAddress
        )
    }
}
