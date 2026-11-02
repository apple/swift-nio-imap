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

@Suite("CompoundObjectID")
struct CompoundObjectIDTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.compoundObjectID(CompoundObjectID(), "()"),
            EncodeFixture.compoundObjectID(CompoundObjectID(mailboxID: "abc123"), "(MAILBOXID abc123)"),
            EncodeFixture.compoundObjectID(CompoundObjectID(accountID: "def456"), "(ACCOUNTID def456)"),
            EncodeFixture.compoundObjectID(CompoundObjectID(emailID: "ghi789"), "(EMAILID ghi789)"),
            EncodeFixture.compoundObjectID(CompoundObjectID(threadID: "jkl012"), "(THREADID jkl012)"),
            EncodeFixture.compoundObjectID(
                CompoundObjectID(mailboxID: "abc123", accountID: "def456", emailID: "ghi789", threadID: "jkl012"),
                "(MAILBOXID abc123 ACCOUNTID def456 EMAILID ghi789 THREADID jkl012)"
            ),
        ]
    )
    func encode(_ fixture: EncodeFixture<CompoundObjectID>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.compoundObjectID("()", expected: .success(CompoundObjectID())),
            ParseFixture.compoundObjectID(
                "(MAILBOXID abc123)",
                expected: .success(CompoundObjectID(mailboxID: "abc123"))
            ),
            ParseFixture.compoundObjectID(
                "(MAILBOXID abc123 ACCOUNTID def456 EMAILID ghi789 THREADID jkl012)",
                expected: .success(
                    CompoundObjectID(mailboxID: "abc123", accountID: "def456", emailID: "ghi789", threadID: "jkl012")
                )
            ),
            ParseFixture.compoundObjectID(
                "(FOO bar123 MAILBOXID abc123)",
                expected: .success(CompoundObjectID(mailboxID: "abc123"))
            ),
        ]
    )
    func parse(_ fixture: ParseFixture<CompoundObjectID>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<CompoundObjectID> {
    fileprivate static func compoundObjectID(_ input: CompoundObjectID, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeCompoundObjectID($1) }
        )
    }
}

extension ParseFixture<CompoundObjectID> {
    fileprivate static func compoundObjectID(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCompoundObjectID
        )
    }
}
