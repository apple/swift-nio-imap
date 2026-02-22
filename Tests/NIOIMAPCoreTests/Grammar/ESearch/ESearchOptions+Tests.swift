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
        )
    ])
    func encode(_ fixture: EncodeFixture<ExtendedSearchOptions>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.extendedSearchOptions(
            " ALL",
            expected: .success(ExtendedSearchOptions(key: .all))
        ),
        ParseFixture.extendedSearchOptions(
            " RETURN (MIN) ALL",
            expected: .success(ExtendedSearchOptions(key: .all, returnOptions: [.min]))
        ),
        ParseFixture.extendedSearchOptions(
            " CHARSET Alien ALL",
            expected: .success(ExtendedSearchOptions(key: .all, charset: "Alien"))
        ),
        ParseFixture.extendedSearchOptions(
            " IN (inboxes) ALL",
            expected: .success(
                ExtendedSearchOptions(
                    key: .all,
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                )
            )
        ),
        ParseFixture.extendedSearchOptions(
            " IN (inboxes) CHARSET Alien ALL",
            expected: .success(
                ExtendedSearchOptions(
                    key: .all,
                    charset: "Alien",
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                )
            )
        ),
        ParseFixture.extendedSearchOptions(
            " IN (inboxes) RETURN (MIN) ALL",
            expected: .success(
                ExtendedSearchOptions(
                    key: .all,
                    returnOptions: [.min],
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                )
            )
        ),
        ParseFixture.extendedSearchOptions(
            " RETURN (MIN) CHARSET Alien ALL",
            expected: .success(
                ExtendedSearchOptions(
                    key: .all,
                    charset: "Alien",
                    returnOptions: [.min]
                )
            )
        ),
        ParseFixture.extendedSearchOptions(
            " IN (inboxes) RETURN (MIN) CHARSET Alien ALL",
            expected: .success(
                ExtendedSearchOptions(
                    key: .all,
                    charset: "Alien",
                    returnOptions: [.min],
                    sourceOptions: ExtendedSearchSourceOptions(sourceMailbox: [.inboxes])
                )
            )
        )
    ])
    func parseExtendedSearchOptions(_ fixture: ParseFixture<ExtendedSearchOptions>) {
        fixture.checkParsing()
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

extension ParseFixture<ExtendedSearchOptions> {
    fileprivate static func extendedSearchOptions(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseExtendedSearchOptions
        )
    }
}
