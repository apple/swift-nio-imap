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

    @Test("valid string init")
    func validStringInit() {
        let valid1: String = "ValidID123"
        #expect(MailboxID(valid1) != nil)
        let valid2: String = "a"
        #expect(MailboxID(valid2) != nil)
    }

    @Test("invalid string init returns nil")
    func invalidStringInitReturnsNil() {
        let empty: String = ""
        #expect(MailboxID(empty) == nil)
        let withSpace: String = "has space"
        #expect(MailboxID(withSpace) == nil)
        let withSymbol: String = "has@symbol"
        #expect(MailboxID(withSymbol) == nil)
    }

    @Test("string conversion")
    func stringConversion() {
        let id: MailboxID = "ValidID"
        #expect(String(id) == "ValidID")
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
