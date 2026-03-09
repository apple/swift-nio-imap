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

@Suite("ListSelectBaseOption")
struct ListSelectBaseOptionTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.listSelectBaseOption(.subscribed, "SUBSCRIBED"),
            EncodeFixture.listSelectBaseOption(.option(.init(key: .standard("test"), value: nil)), "test"),
        ]
    )
    func encode(_ fixture: EncodeFixture<ListSelectBaseOption>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode quoted",
        arguments: [
            EncodeFixture.listSelectBaseOptionQuoted(.subscribed, #""SUBSCRIBED""#)
        ]
    )
    func encodeQuoted(_ fixture: EncodeFixture<ListSelectBaseOption>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.listSelectBaseOption("SUBSCRIBED", ")", expected: .success(.subscribed)),
            ParseFixture.listSelectBaseOption(
                "REMOTE",
                ")",
                expected: .success(.option(.init(key: .standard("REMOTE"), value: nil)))
            ),
            ParseFixture.listSelectBaseOption("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<ListSelectBaseOption>) {
        fixture.checkParsing()
    }

    @Test(
        "parse CHILDINFO extended item",
        arguments: [
            ParseFixture.childinfoExtendedItem(
                #"CHILDINFO ("SUBSCRIBED")"#,
                expected: .success([.subscribed])
            ),
            ParseFixture.childinfoExtendedItem(
                #"CHILDINFO ("SUBSCRIBED" "REMOTE")"#,
                expected: .success([.subscribed, .option(.init(key: .standard("REMOTE"), value: nil))])
            ),
            ParseFixture.childinfoExtendedItem("", "", expected: .incompleteMessage),
        ]
    )
    func parseChildinfoExtendedItem(_ fixture: ParseFixture<[ListSelectBaseOption]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ListSelectBaseOption> {
    fileprivate static func listSelectBaseOption(
        _ input: ListSelectBaseOption,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectBaseOption($1) }
        )
    }

    fileprivate static func listSelectBaseOptionQuoted(
        _ input: ListSelectBaseOption,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectBaseOptionQuoted($1) }
        )
    }
}

extension ParseFixture<ListSelectBaseOption> {
    fileprivate static func listSelectBaseOption(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseListSelectBaseOption
        )
    }
}

extension ParseFixture<[ListSelectBaseOption]> {
    fileprivate static func childinfoExtendedItem(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseChildinfoExtendedItem
        )
    }
}
