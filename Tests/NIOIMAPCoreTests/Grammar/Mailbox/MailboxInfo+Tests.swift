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

@Suite("MailboxInfo")
struct MailboxInfoTests {
    @Test func `attribute hashable`() {
        #expect(
            MailboxInfo.Attribute("test").hashValue == MailboxInfo.Attribute("TEST").hashValue,
            "hashing should be case insensitive"
        )
        #expect(
            MailboxInfo.Attribute("a").hashValue != MailboxInfo.Attribute("b").hashValue
        )
    }

    @Test(arguments: [
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [], path: try! .init(name: .inbox), extensions: [:]),
            #"() NIL "INBOX""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [], path: try! .init(name: .inbox, pathSeparator: "/"), extensions: [:]),
            #"() "/" "INBOX""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(
                attributes: [.noSelect],
                path: try! .init(name: MailboxName("Projects"), pathSeparator: "/"),
                extensions: [:]
            ),
            #"(\Noselect) "/" "Projects""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(
                attributes: [.marked, .hasChildren],
                path: try! .init(name: MailboxName("INBOX"), pathSeparator: "/"),
                extensions: [:]
            ),
            #"(\Marked \HasChildren) "/" "INBOX""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(
                attributes: [.hasNoChildren],
                path: try! .init(name: MailboxName("Sent"), pathSeparator: "/"),
                extensions: [:]
            ),
            #"(\HasNoChildren) "/" "Sent""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(
                attributes: [.noSelect, .hasChildren],
                path: try! .init(name: MailboxName("[Gmail]"), pathSeparator: "/"),
                extensions: [:]
            ),
            #"(\Noselect \HasChildren) "/" "[Gmail]""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(
                attributes: [.subscribed, .hasNoChildren],
                path: try! .init(name: MailboxName("Archive/2024"), pathSeparator: "."),
                extensions: [:]
            ),
            #"(\Subscribed \HasNoChildren) "." "Archive/2024""#
        ),
    ])
    func encode(_ fixture: EncodeFixture<MailboxInfo>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.mailboxListFlags([], ""),
        EncodeFixture.mailboxListFlags([.marked], #"\Marked"#),
        EncodeFixture.mailboxListFlags([.noInferiors], #"\Noinferiors"#),
        EncodeFixture.mailboxListFlags([.marked, .noInferiors, .init(#"\test"#)], #"\Marked \Noinferiors \test"#),
    ])
    func `encode flags`(_ fixture: EncodeFixture<[MailboxInfo.Attribute]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.mailboxInfo(
            "() NIL inbox",
            "\r",
            expected: .success(.init(attributes: [], path: try! .init(name: .inbox), extensions: [:]))
        ),
        ParseFixture.mailboxInfo(
            #"() "d" inbox"#,
            "\r",
            expected: .success(
                .init(attributes: [], path: try! .init(name: .inbox, pathSeparator: "d"), extensions: [:])
            )
        ),
        ParseFixture.mailboxInfo(
            "(\\oflag1 \\oflag2) NIL inbox",
            "\r",
            expected: .success(
                .init(
                    attributes: [.init("\\oflag1"), .init("\\oflag2")],
                    path: try! .init(name: .inbox),
                    extensions: [:]
                )
            )
        ),
        ParseFixture.mailboxInfo(
            #"(\oflag1 \oflag2) "d" inbox"#,
            "\r",
            expected: .success(
                .init(
                    attributes: [.init("\\oflag1"), .init("\\oflag2")],
                    path: try! .init(name: .inbox, pathSeparator: "d"),
                    extensions: [:]
                )
            )
        ),
        ParseFixture.mailboxInfo(#"() ""#, "", expected: .incompleteMessageIgnoringBufferModifications),
        ParseFixture.mailboxInfo(#"() "\" inbox"#, "", expected: .failureIgnoringBufferModifications),
    ])
    func parse(_ fixture: ParseFixture<MailboxInfo>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.mailboxListFlags("\\marked", "\r", expected: .success([.marked])),
        ParseFixture.mailboxListFlags("\\marked \\remote", "\r", expected: .success([.marked, .remote])),
        ParseFixture.mailboxListFlags(
            "\\marked \\o1 \\o2",
            "\r",
            expected: .success([.marked, .init("\\o1"), .init("\\o2")])
        ),
    ])
    func `parse flags`(_ fixture: ParseFixture<[MailboxInfo.Attribute]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MailboxInfo> {
    fileprivate static func mailboxInfo(
        _ input: MailboxInfo,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxInfo($1) }
        )
    }
}

extension EncodeFixture<[MailboxInfo.Attribute]> {
    fileprivate static func mailboxListFlags(
        _ input: [MailboxInfo.Attribute],
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxListFlags($1) }
        )
    }
}

extension ParseFixture<MailboxInfo> {
    fileprivate static func mailboxInfo(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMailboxList
        )
    }
}

extension ParseFixture<[MailboxInfo.Attribute]> {
    fileprivate static func mailboxListFlags(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseMailboxListFlags
        )
    }
}
