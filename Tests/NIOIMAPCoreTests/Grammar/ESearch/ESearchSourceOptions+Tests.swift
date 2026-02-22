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

@Suite("ExtendedSearchSourceOptions")
struct ExtendedSearchSourceOptionsTests {
    @Test(arguments: [
        EncodeFixture.extendedSearchSourceOptions(
            ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])!,
            "IN (inboxes)"
        ),
        EncodeFixture.extendedSearchSourceOptions(
            ExtendedSearchSourceOptions(
                sourceMailbox: [.inboxes],
                scopeOptions: ExtendedSearchScopeOptions(["test": nil])
            )!,
            "IN (inboxes (test))"
        ),
        EncodeFixture.extendedSearchSourceOptions(
            ExtendedSearchSourceOptions(
                sourceMailbox: [.inboxes, .personal],
                scopeOptions: ExtendedSearchScopeOptions(["test": nil])
            )!,
            "IN (inboxes personal (test))"
        )
    ])
    func encode(_ fixture: EncodeFixture<ExtendedSearchSourceOptions>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.extendedSearchSourceOptions(
            "IN (inboxes)",
            expected: .success(ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])!)
        ),
        ParseFixture.extendedSearchSourceOptions(
            "IN (inboxes personal)",
            expected: .success(ExtendedSearchSourceOptions(sourceMailbox: [.inboxes, .personal])!)
        ),
        ParseFixture.extendedSearchSourceOptions(
            "IN (inboxes (name))",
            expected: .success(
                ExtendedSearchSourceOptions(
                    sourceMailbox: [.inboxes],
                    scopeOptions: ExtendedSearchScopeOptions(["name": nil])!
                )!
            )
        ),
        ParseFixture.extendedSearchSourceOptions("IN (inboxes ())", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN ((name))", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN (inboxes (name)", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN (inboxes (name", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN (inboxes (", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN (inboxes )", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN (", expected: .failure),
        ParseFixture.extendedSearchSourceOptions("IN", expected: .failure)
    ])
    func parseExtendedSearchSourceOptions(_ fixture: ParseFixture<ExtendedSearchSourceOptions>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ExtendedSearchSourceOptions> {
    fileprivate static func extendedSearchSourceOptions(
        _ input: ExtendedSearchSourceOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeExtendedSearchSourceOptions($1) }
        )
    }
}

extension ParseFixture<ExtendedSearchSourceOptions> {
    fileprivate static func extendedSearchSourceOptions(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseExtendedSearchSourceOptions
        )
    }
}
