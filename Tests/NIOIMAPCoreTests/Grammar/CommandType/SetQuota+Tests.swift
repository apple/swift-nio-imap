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

@Suite("Quota Commands")
struct QuotaCommandTests {
    @Test(arguments: [
        ParseFixture.setQuota(
            "SETQUOTA \"\" (STORAGE 512)",
            expected: .success(.setQuota(QuotaRoot(""), [QuotaLimit(resourceName: "STORAGE", limit: 512)]))
        ),
        ParseFixture.setQuota(
            "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512)",
            expected: .success(.setQuota(QuotaRoot("MASSIVE_POOL"), [QuotaLimit(resourceName: "STORAGE", limit: 512)]))
        ),
        ParseFixture.setQuota(
            "SETQUOTA \"MASSIVE_POOL\" (STORAGE 512 BEANS 50000)",
            expected: .success(
                .setQuota(
                    QuotaRoot("MASSIVE_POOL"),
                    [
                        QuotaLimit(resourceName: "STORAGE", limit: 512),
                        QuotaLimit(resourceName: "BEANS", limit: 50000)
                    ]
                )
            )
        ),
        ParseFixture.setQuota(
            "SETQUOTA \"MASSIVE_POOL\" ()",
            expected: .success(.setQuota(QuotaRoot("MASSIVE_POOL"), []))
        ),
        ParseFixture.setQuota("SETQUOTA \"MASSIVE_POOL\" (STORAGE BEANS)", expected: .failure),
        ParseFixture.setQuota("SETQUOTA \"MASSIVE_POOL\" (STORAGE 40M)", expected: .failure),
        ParseFixture.setQuota("SETQUOTA \"MASSIVE_POOL\" (STORAGE)", expected: .failure),
        ParseFixture.setQuota("SETQUOTA \"MASSIVE_POOL\" (", expected: .failure),
        ParseFixture.setQuota("SETQUOTA \"MASSIVE_POOL\"", expected: .failure)
    ])
    func parseSetQuota(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.getQuota("GETQUOTA \"\"", expected: .success(.getQuota(QuotaRoot("")))),
        ParseFixture.getQuota("GETQUOTA \"MASSIVE_POOL\"", expected: .success(.getQuota(QuotaRoot("MASSIVE_POOL")))),
        ParseFixture.getQuota("GETQUOTA", expected: .failure)
    ])
    func parseGetQuota(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.getQuotaRoot("GETQUOTAROOT INBOX", expected: .success(.getQuotaRoot(MailboxName("INBOX")))),
        ParseFixture.getQuotaRoot("GETQUOTAROOT Other", expected: .success(.getQuotaRoot(MailboxName("Other")))),
        ParseFixture.getQuotaRoot("GETQUOTAROOT", expected: .failure)
    ])
    func parseGetQuotaRoot(_ fixture: ParseFixture<Command>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension ParseFixture<Command> {
    fileprivate static func setQuota(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommand
        )
    }

    fileprivate static func getQuota(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommand
        )
    }

    fileprivate static func getQuotaRoot(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCommand
        )
    }
}
