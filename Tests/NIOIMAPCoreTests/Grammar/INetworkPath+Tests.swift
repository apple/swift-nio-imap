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

@Suite("NetworkPath")
struct NetworkPathTests {
    @Test(arguments: [
        EncodeFixture.networkPath(
            .init(server: .init(host: "localhost"), query: nil),
            "//localhost/"
        ),
        EncodeFixture.networkPath(
            .init(
                server: .init(
                    userAuthenticationMechanism: .init(encodedUser: .init(data: "user"), authenticationMechanism: nil),
                    host: "mail.example.com"
                ),
                query: .messageList(
                    .init(
                        mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "INBOX"), uidValidity: nil),
                        encodedSearch: nil
                    )
                )
            ),
            "//user@mail.example.com/INBOX"
        ),
    ])
    func encode(_ fixture: EncodeFixture<NetworkPath>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.networkPath(
            "//localhost/",
            " ",
            expected: .success(.init(server: .init(host: "localhost"), query: nil))
        ),
        ParseFixture.networkPath(
            "//localhost/test/;UID=123",
            " ",
            expected: .success(
                .init(
                    server: .init(host: "localhost"),
                    query: .fetch(
                        path: .init(
                            mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                            iUID: .init(uid: 123)
                        ),
                        authenticatedURL: nil
                    )
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<NetworkPath>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<NetworkPath> {
    fileprivate static func networkPath(
        _ input: NetworkPath,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeNetworkPath($1) }
        )
    }
}

extension ParseFixture<NetworkPath> {
    fileprivate static func networkPath(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseNetworkPath
        )
    }
}
