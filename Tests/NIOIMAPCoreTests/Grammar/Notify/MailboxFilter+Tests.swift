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

@Suite("MailboxFilter")
struct MailboxFilterTests {
    @Test(arguments: [
        EncodeFixture.mailboxFilter(
            .inboxes,
            "inboxes"
        ),
        EncodeFixture.mailboxFilter(
            .personal,
            "personal"
        ),
        EncodeFixture.mailboxFilter(
            .subscribed,
            "subscribed"
        ),
        EncodeFixture.mailboxFilter(
            .subtree(Mailboxes([.init("box1")])!),
            "subtree (\"box1\")"
        ),
        EncodeFixture.mailboxFilter(
            .mailboxes(Mailboxes([.init("box1")])!),
            "mailboxes (\"box1\")"
        ),
        EncodeFixture.mailboxFilter(
            .selected,
            "selected"
        ),
        EncodeFixture.mailboxFilter(
            .selectedDelayed,
            "selected-delayed"
        ),
        EncodeFixture.mailboxFilter(
            .subtreeOne(Mailboxes([.init("box1")])!),
            "subtree-one (\"box1\")"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MailboxFilter>) {
        fixture.checkEncoding()
    }

    @Test("parse filter mailboxes", arguments: [
        ParseFixture.filterMailboxes("inboxes", " ", expected: .success(.inboxes)),
        ParseFixture.filterMailboxes("personal", " ", expected: .success(.personal)),
        ParseFixture.filterMailboxes("subscribed", " ", expected: .success(.subscribed)),
        ParseFixture.filterMailboxes("selected", " ", expected: .success(.selected)),
        ParseFixture.filterMailboxes("selected-delayed", " ", expected: .success(.selectedDelayed)),
        ParseFixture.filterMailboxes(
            "subtree \"box1\"",
            " ",
            expected: .success(.subtree(Mailboxes([.init("box1")])!))
        ),
        ParseFixture.filterMailboxes(
            "subtree-one \"box1\"",
            " ",
            expected: .success(.subtreeOne(Mailboxes([.init("box1")])!))
        ),
        ParseFixture.filterMailboxes(
            "mailboxes \"box1\"",
            " ",
            expected: .success(.mailboxes(Mailboxes([.init("box1")])!))
        ),
        ParseFixture.filterMailboxes("subtree ", expected: .failure),
        ParseFixture.filterMailboxes("subtree-one", expected: .failure),
        ParseFixture.filterMailboxes("mailboxes", expected: .failure),
    ])
    func parseFilterMailboxes(_ fixture: ParseFixture<MailboxFilter>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MailboxFilter> {
    fileprivate static func mailboxFilter(
        _ input: MailboxFilter,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxFilter($1) }
        )
    }
}

extension ParseFixture<MailboxFilter> {
    fileprivate static func filterMailboxes(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFilterMailboxes
        )
    }
}
