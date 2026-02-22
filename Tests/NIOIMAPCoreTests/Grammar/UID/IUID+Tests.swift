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

@Suite("IUID")
struct IUIDTests {
    @Test(arguments: [
        EncodeFixture.iuid(.init(uid: 123), "/;UID=123")
    ])
    func encode(_ fixture: EncodeFixture<IUID>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode UID only",
        arguments: [
            EncodeFixture.iuidOnly(.init(uid: 123), ";UID=123")
        ]
    )
    func encodeUIDOnly(_ fixture: EncodeFixture<IUID>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse with slash",
        arguments: [
            ParseFixture.parseWithSlash("/;UID=1", " ", expected: .success(.init(uid: 1))),
            ParseFixture.parseWithSlash("/;UID=12", " ", expected: .success(.init(uid: 12))),
            ParseFixture.parseWithSlash("/;UID=123", " ", expected: .success(.init(uid: 123))),
            ParseFixture.parseWithSlash("a", " ", expected: .failure),
            ParseFixture.parseWithSlash("/;UID=1", "", expected: .incompleteMessage)
        ]
    )
    func parseWithSlash(_ fixture: ParseFixture<IUID>) {
        fixture.checkParsing()
    }

    @Test(
        "parse without slash",
        arguments: [
            ParseFixture.parseWithoutSlash(";UID=1", " ", expected: .success(.init(uid: 1))),
            ParseFixture.parseWithoutSlash(";UID=12", " ", expected: .success(.init(uid: 12))),
            ParseFixture.parseWithoutSlash(";UID=123", " ", expected: .success(.init(uid: 123))),
            ParseFixture.parseWithoutSlash("a", " ", expected: .failure),
            ParseFixture.parseWithoutSlash(";UID=1", "", expected: .incompleteMessage)
        ]
    )
    func parseWithoutSlash(_ fixture: ParseFixture<IUID>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<IUID> {
    fileprivate static func iuid(
        _ input: IUID,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIUID($1) }
        )
    }

    fileprivate static func iuidOnly(
        _ input: IUID,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeIUIDOnly($1) }
        )
    }
}

extension ParseFixture<IUID> {
    fileprivate static func parseWithSlash(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIUID
        )
    }

    fileprivate static func parseWithoutSlash(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseIUIDOnly
        )
    }
}
