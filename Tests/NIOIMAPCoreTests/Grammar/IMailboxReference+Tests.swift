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

@Suite("Mailbox UID Validity")
struct EncodedMailboxUIDValidityTests {
    @Test(arguments: [
        EncodeFixture.mailboxUIDValidity(
            .init(encodeMailbox: .init(mailbox: "mailbox"), uidValidity: nil),
            "mailbox"
        ),
        EncodeFixture.mailboxUIDValidity(
            .init(encodeMailbox: .init(mailbox: "mailbox"), uidValidity: 123),
            "mailbox;UIDVALIDITY=123"
        ),
    ])
    func encode(_ fixture: EncodeFixture<MailboxUIDValidity>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.mailboxUIDValidity(
            "abc",
            " ",
            expected: .success(.init(encodeMailbox: .init(mailbox: "abc"), uidValidity: nil))
        ),
        ParseFixture.mailboxUIDValidity(
            "abc;UIDVALIDITY=123",
            " ",
            expected: .success(.init(encodeMailbox: .init(mailbox: "abc"), uidValidity: 123))
        ),
        ParseFixture.mailboxUIDValidity(
            "¢",
            " ",
            expected: .failure
        ),
        ParseFixture.mailboxUIDValidity(
            "abc",
            "",
            expected: .incompleteMessage
        ),
        ParseFixture.mailboxUIDValidity(
            "abc123",
            "",
            expected: .incompleteMessage
        ),
    ])
    func parse(_ fixture: ParseFixture<MailboxUIDValidity>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<MailboxUIDValidity> {
    fileprivate static func mailboxUIDValidity(
        _ input: MailboxUIDValidity,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEncodedMailboxUIDValidity($1) }
        )
    }
}

extension ParseFixture<MailboxUIDValidity> {
    fileprivate static func mailboxUIDValidity(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedMailboxUIDValidity
        )
    }
}
