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

@Suite("ExtendedSearchOptions")
struct ExtendedSearchOptionsTests {
    @Test(arguments: [
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(key: .all),
            " ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(key: .all, returnOptions: [.min]),
            " RETURN (MIN) ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(key: .deleted, returnOptions: [.min, .all]),
            " RETURN (MIN ALL) DELETED"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(key: .deleted, returnOptions: [.all]),
            " RETURN (ALL) DELETED"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(key: .all, charset: "Alien"),
            " CHARSET Alien ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(key: .all, sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])),
            " IN (inboxes) ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(
                key: .all,
                charset: "Alien",
                sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
            ),
            " IN (inboxes) CHARSET Alien ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(
                key: .all,
                returnOptions: [.min],
                sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
            ),
            " IN (inboxes) RETURN (MIN) ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(
                key: .all,
                charset: "Alien",
                returnOptions: [.min]
            ),
            " RETURN (MIN) CHARSET Alien ALL"
        ),
        EncodeFixture.extendedSearchOptions(
            ExtendedSearchOptions(
                key: .all,
                charset: "Alien",
                returnOptions: [.min],
                sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
            ),
            " IN (inboxes) RETURN (MIN) CHARSET Alien ALL"
        ),
    ])
    func encode(_ fixture: EncodeFixture<ExtendedSearchOptions>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<ExtendedSearchOptions> {
    fileprivate static func extendedSearchOptions(
        _ input: ExtendedSearchOptions,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeExtendedSearchOptions($1) }
        )
    }
}
