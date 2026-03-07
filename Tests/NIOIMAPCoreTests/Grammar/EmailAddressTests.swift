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

    @Test("encode email address", arguments: [
        EmailAddressFixture(
            name: "all nil",
            address: .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
            expectedString: "(NIL NIL NIL NIL)"
        ),
        EmailAddressFixture(
            name: "none nil",
            address: .init(personName: "somename", sourceRoot: "someadl", mailbox: "somemailbox", host: "someaddress"),
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
    ])
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

    @Test("parse envelope email address groups", arguments: [
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
                        children: [.singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"))]
                    )
                )
            ]
        ),
        EnvelopeGroupingFixture(
            addresses: [
                .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil)
            ],
            expected: [
                .singleAddress(.init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil))
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
                            .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                            .singleAddress(.init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")),
                            .singleAddress(.init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c")),
                        ]
                    )
                )
            ]
        ),
        EnvelopeGroupingFixture(
            addresses: [
                .init(personName: nil, sourceRoot: nil, mailbox: "group1", host: nil),
                .init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a"),
                .init(personName: nil, sourceRoot: nil, mailbox: "group2", host: nil),
                .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b"),
                .init(personName: nil, sourceRoot: nil, mailbox: "group3", host: nil),
                .init(personName: "c", sourceRoot: "c", mailbox: "c", host: "c"),
                .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
                .init(personName: nil, sourceRoot: nil, mailbox: nil, host: nil),
            ],
            expected: [
                .group(
                    .init(
                        groupName: "group1",
                        sourceRoot: nil,
                        children: [
                            .singleAddress(.init(personName: "a", sourceRoot: "a", mailbox: "a", host: "a")),
                            .group(
                                .init(
                                    groupName: "group2",
                                    sourceRoot: nil,
                                    children: [
                                        .singleAddress(
                                            .init(personName: "b", sourceRoot: "b", mailbox: "b", host: "b")
                                        ),
                                        .group(
                                            .init(
                                                groupName: "group3",
                                                sourceRoot: nil,
                                                children: [
                                                    .singleAddress(
                                                        .init(
                                                            personName: "c",
                                                            sourceRoot: "c",
                                                            mailbox: "c",
                                                            host: "c"
                                                        )
                                                    )
                                                ]
                                            )
                                        ),
                                    ]
                                )
                            ),
                        ]
                    )
                )
            ]
        ),
    ])
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
    var addresses: [EmailAddress]
    var expected: [EmailAddressListElement]

    var testDescription: String {
        "grouping \(addresses.count) addresses into \(expected.count) elements"
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
