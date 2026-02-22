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

@Suite("RumpAuthenticatedURL")
struct RumpAuthenticatedURLTests {
    @Test(arguments: [
        EncodeFixture.rumpAuthenticatedURL(
            .init(
                authenticatedURL: .init(
                    server: .init(host: "localhost"),
                    messagePath: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123)
                    )
                ),
                authenticatedURLRump: .init(access: .anonymous)
            ),
            "imap://localhost/test/;UID=123;URLAUTH=anonymous"
        ),
        EncodeFixture.rumpAuthenticatedURL(
            .init(
                authenticatedURL: .init(
                    server: .init(host: "mail.example.com"),
                    messagePath: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "INBOX")),
                        iUID: .init(uid: 456)
                    )
                ),
                authenticatedURLRump: .init(access: .user(.init(data: "testuser")))
            ),
            "imap://mail.example.com/INBOX/;UID=456;URLAUTH=user+testuser"
        )
    ])
    func encode(_ fixture: EncodeFixture<RumpAuthenticatedURL>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.rumpAuthenticatedURL(
            "imap://localhost/test/;UID=123;URLAUTH=anonymous",
            " ",
            expected: .success(
                .init(
                    authenticatedURL: .init(
                        server: .init(host: "localhost"),
                        messagePath: .init(
                            mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                            iUID: .init(uid: 123)
                        )
                    ),
                    authenticatedURLRump: .init(access: .anonymous)
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<RumpAuthenticatedURL>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<RumpAuthenticatedURL> {
    fileprivate static func rumpAuthenticatedURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeAuthIMAPURLRump($1) }
        )
    }
}

extension ParseFixture<RumpAuthenticatedURL> {
    fileprivate static func rumpAuthenticatedURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthIMAPURLRump
        )
    }
}
