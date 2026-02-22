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

@Suite("Mailbox")
struct MailboxTests {
    @Test(arguments: [
        EncodeFixture.mailbox(.inbox, #""INBOX""#),
        EncodeFixture.mailbox(.init(""), #""""#),
        EncodeFixture.mailbox(.init("box"), #""box""#),
        EncodeFixture.mailbox(.init(#"a"b"#), #""a\"b""#),
        EncodeFixture.mailbox(.init(ByteBuffer(string: #"&ltFO9g-\"#)), #""&ltFO9g-\\""#),
    ])
    func encode(_ fixture: EncodeFixture<MailboxName>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<MailboxName> {
    fileprivate static func mailbox(
        _ input: MailboxName,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailbox($1) }
        )
    }
}
