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
