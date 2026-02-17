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

@Suite("EncodedMailbox")
struct EncodedMailboxTests {
    @Test(arguments: [
        EncodeFixture.encodedMailbox(.init(mailbox: "hello"), "hello")
    ])
    func encode(_ fixture: EncodeFixture<EncodedMailbox>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.encodedMailbox(
            "hello%FF",
            " ",
            expected: .success(.init(mailbox: "hello%FF"))
        )
    ])
    func parse(_ fixture: ParseFixture<EncodedMailbox>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<EncodedMailbox> {
    fileprivate static func encodedMailbox(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEncodedMailbox($1) }
        )
    }
}

extension ParseFixture<EncodedMailbox> {
    fileprivate static func encodedMailbox(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedMailbox
        )
    }
}
