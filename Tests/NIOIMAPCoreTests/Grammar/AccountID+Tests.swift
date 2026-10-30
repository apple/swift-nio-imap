//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

@Suite("AccountID")
struct AccountIDTests {
    @Test(
        "failable init",
        arguments: [
            ("abc123", true),
            ("ABC-XYZ_123", true),
            ("a", true),
            (String(repeating: "a", count: 255), true),
            ("", false),
            ("abc!", false),
            (String(repeating: "a", count: 256), false),
        ] as [(String, Bool)]
    )
    func faillableInit(_ fixture: (String, Bool)) {
        let result = AccountID(fixture.0)
        #expect((result != nil) == fixture.1)
    }

    @Test(
        "string conversion",
        arguments: [
            ("abc123", "abc123"),
            ("ABC-XYZ_123", "ABC-XYZ_123"),
        ] as [(String, String)]
    )
    func stringConversion(_ fixture: (String, String)) {
        let id = AccountID(fixture.0)!
        #expect(String(id) == fixture.1)
    }

    @Test("string literal init")
    func stringLiteralInit() {
        let id: AccountID = "abc123"
        #expect(String(id) == "abc123")
    }

    @Test(
        "debug description",
        arguments: [
            ("abc123", "(abc123)"),
            ("XYZ-789", "(XYZ-789)"),
        ] as [(String, String)]
    )
    func debugDescription(_ fixture: (String, String)) {
        let id = AccountID(fixture.0)!
        #expect(id.debugDescription == fixture.1)
    }

    @Test(
        "encode",
        arguments: [
            EncodeFixture.accountID("abc123", "abc123"),
            EncodeFixture.accountID("XYZ-789_000", "XYZ-789_000"),
        ]
    )
    func encode(_ fixture: EncodeFixture<AccountID>) {
        fixture.checkEncoding()
    }
}

// MARK: - Fixtures

extension EncodeFixture<AccountID> {
    fileprivate static func accountID(_ rawValue: String, _ expectedString: String) -> Self {
        EncodeFixture(
            input: AccountID(rawValue)!,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeAccountID($1) }
        )
    }
}
