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

@Suite("AbsoluteMessagePath")
struct AbsoluteMessagePathTests {
    @Test(arguments: [
        EncodeFixture.absoluteMessagePath(
            .init(command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"))))),
            "/test"
        ),
        EncodeFixture.absoluteMessagePath(
            .init(command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "INBOX"))))),
            "/INBOX"
        )
    ])
    func encode(_ fixture: EncodeFixture<AbsoluteMessagePath>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.absoluteMessagePath("/", " ", expected: .success(.init(command: nil))),
        ParseFixture.absoluteMessagePath(
            "/test",
            " ",
            expected: .success(
                .init(
                    command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"))))
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<AbsoluteMessagePath>) {
        fixture.checkParsing()
    }
}

extension EncodeFixture<AbsoluteMessagePath> {
    fileprivate static func absoluteMessagePath(_ input: T, _ expectedString: String) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedStrings: [expectedString],
            encoder: { $0.writeAbsoluteMessagePath($1) }
        )
    }
}

extension ParseFixture<AbsoluteMessagePath> {
    fileprivate static func absoluteMessagePath(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAbsoluteMessagePath
        )
    }
}
