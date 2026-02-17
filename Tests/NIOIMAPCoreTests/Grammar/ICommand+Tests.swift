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

@Suite("URL Command")
struct URLCommandTests {
    @Test(arguments: [
        EncodeFixture.urlCommand(
            .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test")))),
            "test"
        ),
        EncodeFixture.urlCommand(
            .fetch(
                path: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123)),
                authenticatedURL: nil
            ),
            "test/;UID=123"
        ),
        EncodeFixture.urlCommand(
            .fetch(
                path: .init(mailboxReference: .init(encodeMailbox: .init(mailbox: "test")), iUID: .init(uid: 123)),
                authenticatedURL: .init(
                    authenticatedURL: .init(access: .anonymous),
                    verifier: .init(
                        urlAuthMechanism: .internal,
                        encodedAuthenticationURL: .init(data: "01234567890123456789012345678901")
                    )
                )
            ),
            "test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901"
        ),
    ])
    func encode(_ fixture: EncodeFixture<URLCommand>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.urlCommand(
            "test",
            " ",
            expected: .success(
                .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"))))
            )
        ),
        ParseFixture.urlCommand(
            "test/;UID=123",
            " ",
            expected: .success(
                .fetch(
                    path: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123)
                    ),
                    authenticatedURL: nil
                )
            )
        ),
        ParseFixture.urlCommand(
            "test/;UID=123;URLAUTH=anonymous:INTERNAL:01234567890123456789012345678901",
            " ",
            expected: .success(
                .fetch(
                    path: .init(
                        mailboxReference: .init(encodeMailbox: .init(mailbox: "test")),
                        iUID: .init(uid: 123)
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
        ),
    ])
    func parse(_ fixture: ParseFixture<URLCommand>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<URLCommand> {
    fileprivate static func urlCommand(
        _ input: URLCommand,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeURLCommand($1) }
        )
    }
}

extension ParseFixture<URLCommand> {
    fileprivate static func urlCommand(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseURLCommand
        )
    }
}
