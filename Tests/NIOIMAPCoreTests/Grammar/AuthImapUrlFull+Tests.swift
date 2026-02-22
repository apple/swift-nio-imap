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

@Suite("FullAuthenticatedURL")
struct FullAuthenticatedURLTests {
    @Test(arguments: [
        EncodeFixture.fullAuthenticatedURL(
            .init(
                networkMessagePath: .init(
                    server: .init(host: "localhost"),
                    messagePath: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123)
                    )
                ),
                authenticatedURL: .init(
                    authenticatedURL: .init(access: .anonymous),
                    verifier: .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "data"))
                )
            ),
            "imap://localhost/test/;UID=123;URLAUTH=anonymous:INTERNAL:data"
        ),
        EncodeFixture.fullAuthenticatedURL(
            .init(
                networkMessagePath: .init(
                    server: .init(host: "mail.example.com"),
                    messagePath: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "INBOX")),
                        iUID: .init(uid: 789)
                    )
                ),
                authenticatedURL: .init(
                    authenticatedURL: .init(access: .user(.init(data: "alice"))),
                    verifier: .init(urlAuthMechanism: .internal, encodedAuthenticationURL: .init(data: "verifier123"))
                )
            ),
            "imap://mail.example.com/INBOX/;UID=789;URLAUTH=user+alice:INTERNAL:verifier123"
        )
    ])
    func encode(_ fixture: EncodeFixture<FullAuthenticatedURL>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.fullAuthenticatedURL(
            "imap://localhost/test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901",
            " ",
            expected: .success(
                .init(
                    networkMessagePath: .init(
                        server: .init(host: "localhost"),
                        messagePath: .init(
                            mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                            iUID: .init(uid: 123)
                        )
                    ),
                    authenticatedURL: .init(
                        authenticatedURL: .init(access: .anonymous),
                        verifier: .init(
                            urlAuthMechanism: .internal,
                            encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
                        )
                    )
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<FullAuthenticatedURL>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<FullAuthenticatedURL> {
    fileprivate static func fullAuthenticatedURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeAuthIMAPURLFull($1) }
        )
    }
}

extension ParseFixture<FullAuthenticatedURL> {
    fileprivate static func fullAuthenticatedURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAuthIMAPURLFull
        )
    }
}
