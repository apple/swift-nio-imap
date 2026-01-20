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
