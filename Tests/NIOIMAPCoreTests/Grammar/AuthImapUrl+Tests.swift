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

@Suite("AuthImapUrl")
struct AuthImapUrlTests {
    @Test(arguments: [
        EncodeFixture.authenticatedURL(
            .init(
                server: .init(host: "localhost"),
                messagePath: .init(
                    mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                    iUID: .init(uid: 123)
                )
            ),
            "imap://localhost/test/;UID=123"
        ),
        EncodeFixture.authenticatedURL(
            .init(
                server: .init(host: "mail.example.com", port: 993),
                messagePath: .init(
                    mailboxReference: .init(encodeMailbox: .init(mailbox: "INBOX")),
                    iUID: .init(uid: 999)
                )
            ),
            "imap://mail.example.com:993/INBOX/;UID=999"
        ),
    ])
    func encode(_ fixture: EncodeFixture<NetworkMessagePath>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.authenticatedURL(
            "imap://localhost/test/;UID=123",
            " ",
            expected: .success(
                .init(
                    server: .init(host: "localhost"),
                    messagePath: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123)
                    )
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<NetworkMessagePath>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<NetworkMessagePath> {
    fileprivate static func authenticatedURL(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAuthenticatedURL($1) }
        )
    }
}

extension ParseFixture<NetworkMessagePath> {
    fileprivate static func authenticatedURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthenticatedURL
        )
    }
}
