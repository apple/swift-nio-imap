//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2024 Apple Inc. and the SwiftNIO project authors
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

@Suite("MailboxID")
struct MailboxIDTests {
    @Test(arguments: [
        EncodeFixture.mailboxID("Abc123", "Abc123"),
        EncodeFixture.mailboxID("a-b_c", "a-b_c"),
    ])
    func encode(_ fixture: EncodeFixture<MailboxID>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ("ValidID123", true),
        ("a", true),
        ("", false),
        ("has space", false),
        ("has@symbol", false),
    ] as [(String, Bool)])
    func stringInit(_ fixture: (String, Bool)) {
        #expect((MailboxID(fixture.0) != nil) == fixture.1)
    }

    @Test(arguments: [
        ("ValidID", "ValidID"),
    ] as [(MailboxID, String)])
    func stringConversion(_ fixture: (MailboxID, String)) {
        #expect(String(fixture.0) == fixture.1)
    }
}

// MARK: -

extension EncodeFixture<MailboxID> {
    fileprivate static func mailboxID(_ input: MailboxID, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeMailboxID($1) }
        )
    }
}
