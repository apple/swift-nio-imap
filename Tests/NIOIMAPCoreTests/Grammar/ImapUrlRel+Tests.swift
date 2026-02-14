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

@Suite("RelativeIMAPURL")
struct RelativeIMAPURLTests {
    @Test(arguments: [
        EncodeFixture.relativeIMAPURL(
            .absolutePath(
                .init(
                    command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"))))
                )
            ),
            "/test"
        ),
        EncodeFixture.relativeIMAPURL(
            .networkPath(.init(server: .init(host: "localhost"), query: nil)),
            "//localhost/"
        ),
        EncodeFixture.relativeIMAPURL(
            .empty,
            ""
        ),
    ])
    func encode(_ fixture: EncodeFixture<RelativeIMAPURL>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.relativeIMAPURL(
            "/test",
            " ",
            expected: .success(.absolutePath(
                .init(
                    command: .messageList(
                        .init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test")))
                    )
                )
            ))
        ),
        ParseFixture.relativeIMAPURL(
            "//localhost/",
            " ",
            expected: .success(.networkPath(.init(server: .init(host: "localhost"), query: nil)))
        ),
        ParseFixture.relativeIMAPURL(
            "",
            " ",
            expected: .success(.empty)
        ),
    ])
    func parse(_ fixture: ParseFixture<RelativeIMAPURL>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<RelativeIMAPURL> {
    fileprivate static func relativeIMAPURL(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeRelativeIMAPURL($1) }
        )
    }
}

extension ParseFixture<RelativeIMAPURL> {
    fileprivate static func relativeIMAPURL(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseRelativeIMAPURL
        )
    }
}
