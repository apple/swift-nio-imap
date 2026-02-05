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
            MailboxInfo.Attribute("test").hashValue ==
            MailboxInfo.Attribute("TEST").hashValue,
            "hashing should be case insensitive"
        )
        #expect(
            MailboxInfo.Attribute("a").hashValue !=
            MailboxInfo.Attribute("b").hashValue
        )
    }

    @Test(arguments: [
        EncodeFixture.mailboxInfo(MailboxInfo(attributes: [], path: try! .init(name: .inbox), extensions: [:]), #"() NIL "INBOX""#),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [], path: try! .init(name: .inbox, pathSeparator: "/"), extensions: [:]),
            #"() "/" "INBOX""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [.noSelect], path: try! .init(name: MailboxName("Projects"), pathSeparator: "/"), extensions: [:]),
            #"(\Noselect) "/" "Projects""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [.marked, .hasChildren], path: try! .init(name: MailboxName("INBOX"), pathSeparator: "/"), extensions: [:]),
            #"(\Marked \HasChildren) "/" "INBOX""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [.hasNoChildren], path: try! .init(name: MailboxName("Sent"), pathSeparator: "/"), extensions: [:]),
            #"(\HasNoChildren) "/" "Sent""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [.noSelect, .hasChildren], path: try! .init(name: MailboxName("[Gmail]"), pathSeparator: "/"), extensions: [:]),
            #"(\Noselect \HasChildren) "/" "[Gmail]""#
        ),
        EncodeFixture.mailboxInfo(
            MailboxInfo(attributes: [.subscribed, .hasNoChildren], path: try! .init(name: MailboxName("Archive/2024"), pathSeparator: "."), extensions: [:]),
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
