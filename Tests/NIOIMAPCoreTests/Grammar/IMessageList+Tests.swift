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

@Suite("EncodedSearchQuery")
struct EncodedSearchQueryTests {
    @Test(arguments: [
        EncodeFixture.encodedSearchQuery(
            .init(
                mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "box"), uidValidity: nil),
                encodedSearch: nil
            ),
            "box"
        ),
        EncodeFixture.encodedSearchQuery(
            .init(
                mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "box"), uidValidity: nil),
                encodedSearch: .init(query: "search")
            ),
            "box?search"
        ),
    ])
    func encode(_ fixture: EncodeFixture<EncodedSearchQuery>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.encodedSearchQuery(
            "test",
            " ",
            expected: .success(
                .init(mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"), uidValidity: nil))
            )
        ),
        ParseFixture.encodedSearchQuery(
            "test?query",
            " ",
            expected: .success(
                .init(
                    mailboxUIDValidity: .init(encodeMailbox: .init(mailbox: "test"), uidValidity: nil),
                    encodedSearch: .init(query: "query")
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<EncodedSearchQuery>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<EncodedSearchQuery> {
    fileprivate static func encodedSearchQuery(
        _ input: EncodedSearchQuery,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeEncodedSearchQuery($1) }
        )
    }
}

extension ParseFixture<EncodedSearchQuery> {
    fileprivate static func encodedSearchQuery(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseEncodedSearchQuery
        )
    }
}
