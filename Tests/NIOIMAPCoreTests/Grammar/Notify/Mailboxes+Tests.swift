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

@Suite("Mailboxes")
struct MailboxesTests {
    @Test
    func `rejects empty mailbox list`() {
        #expect(Mailboxes([]) == nil)
        #expect(Mailboxes([.inbox]) != nil)
    }

    @Test(arguments: [
        EncodeFixture.mailboxes(
            Mailboxes([.init("box1")])!,
            "(\"box1\")"
        ),
        EncodeFixture.mailboxes(
            Mailboxes([.init("box1"), .init("box2")])!,
            "(\"box1\" \"box2\")"
        ),
    ])
    func encode(_ fixture: EncodeFixture<Mailboxes>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<Mailboxes> {
    fileprivate static func mailboxes(
        _ input: Mailboxes,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxes($1) }
        )
    }
}
