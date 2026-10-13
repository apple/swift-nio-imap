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
        ParseFixture.absoluteMessagePath("/", " ", expected: .success(.init(command: nil))),
        ParseFixture.absoluteMessagePath(
            "/test",
            " ",
            expected: .success(
                .init(
                    command: .messageList(.init(mailboxUIDValidity: .init(encodeMailbox: "test")))
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<AbsoluteMessagePath>) {
        fixture.checkParsing()
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
