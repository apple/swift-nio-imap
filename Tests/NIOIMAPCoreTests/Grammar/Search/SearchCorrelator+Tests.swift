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

@Suite("SearchCorrelator")
struct SearchCorrelatorTests {
    @Test(arguments: [
        EncodeFixture.searchCorrelator(SearchCorrelator(tag: "A543"), #" (TAG "A543")"#),
        EncodeFixture.searchCorrelator(
            SearchCorrelator(tag: "some", mailbox: MailboxName("mb"), uidValidity: 5),
            #" (TAG "some" MAILBOX "mb" UIDVALIDITY 5)"#
        ),
    ])
    func encode(_ fixture: EncodeFixture<SearchCorrelator>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.searchCorrelator(
            " (TAG \"test1\")",
            expected: .success(SearchCorrelator(tag: "test1"))
        ),
        ParseFixture.searchCorrelator(
            " (TAG \"test2\")",
            expected: .success(SearchCorrelator(tag: "test2"))
        ),
        ParseFixture.searchCorrelator(
            " (TAG \"test1\" MAILBOX \"mb\" UIDVALIDITY 5)",
            expected: .success(SearchCorrelator(tag: "test1", mailbox: MailboxName("mb"), uidValidity: 5))
        ),
        ParseFixture.searchCorrelator(
            " (MAILBOX \"mb\" UIDVALIDITY 5 TAG \"test1\")",
            expected: .success(SearchCorrelator(tag: "test1", mailbox: MailboxName("mb"), uidValidity: 5))
        ),
        ParseFixture.searchCorrelator(
            " (TAG \"test1\" MAILBOX \"mb\" )",
            expected: .failure
        ),
        ParseFixture.searchCorrelator(
            " (TAG \"test1\" MAILBOX \"mb\")",
            expected: .failure
        ),
        ParseFixture.searchCorrelator(
            " (TAG \"test1\" MAILBOX \"mb\" MAILBOX \"mb\")",
            expected: .failure
        ),
        ParseFixture.searchCorrelator(
            " (MAILBOX \"mb\")",
            expected: .failure
        ),
        ParseFixture.searchCorrelator(
            " (UIDVALIDITY 5)",
            expected: .failure
        ),
    ])
    func parse(_ fixture: ParseFixture<SearchCorrelator>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SearchCorrelator> {
    fileprivate static func searchCorrelator(
        _ input: SearchCorrelator,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchCorrelator($1) }
        )
    }
}

extension ParseFixture<SearchCorrelator> {
    fileprivate static func searchCorrelator(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSearchCorrelator
        )
    }
}
