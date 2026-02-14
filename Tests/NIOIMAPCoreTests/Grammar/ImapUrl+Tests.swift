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

@Suite("IMAPURL")
struct IMAPURLTests {
    @Test(arguments: [
        EncodeFixture.imapURL(
            .init(server: .init(host: "localhost"), query: nil),
            "imap://localhost/"
        ),
        EncodeFixture.imapURL(
            .init(server: .init(host: "mail.example.com"), query: nil),
            "imap://mail.example.com/"
        ),
    ])
    func encode(_ fixture: EncodeFixture<IMAPURL>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.imapURL(
            "imap://localhost/",
            " ",
            expected: .success(.init(server: .init(host: "localhost"), query: nil))
        ),
        ParseFixture.imapURL(
            "imap://localhost/test/;UID=123",
            " ",
            expected: .success(.init(
                server: .init(host: "localhost"),
                query: .fetch(
                    path: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123)
                    ),
                    authenticatedURL: nil
                )
            ))
        ),
    ])
    func parse(_ fixture: ParseFixture<IMAPURL>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<IMAPURL> {
    fileprivate static func imapURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeIMAPURL($1) }
        )
    }
}

extension ParseFixture<IMAPURL> {
    fileprivate static func imapURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIMAPURL
        )
    }
}
