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
import Testing
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

@Suite("ListSelectOption")
struct ListSelectOptionTests {
    @Test(
        "encode single option",
        arguments: [
            EncodeFixture.listSelectOption(.subscribed, "SUBSCRIBED"),
            EncodeFixture.listSelectOption(.remote, "REMOTE"),
            EncodeFixture.listSelectOption(.recursiveMatch, "RECURSIVEMATCH"),
            EncodeFixture.listSelectOption(.specialUse, "SPECIAL-USE"),
            EncodeFixture.listSelectOption(
                .option(.init(key: .standard("MYEXT"), value: nil)),
                "MYEXT"
            ),
        ]
    )
    func encodeSingleOption(_ fixture: EncodeFixture<ListSelectOption>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode multiple options",
        arguments: [
            EncodeFixture.listSelectOptions(nil, "()"),
            EncodeFixture.listSelectOptions(
                .init(baseOption: .subscribed, options: [.subscribed]),
                "(SUBSCRIBED SUBSCRIBED)"
            ),
            EncodeFixture.listSelectOptions(
                .init(baseOption: .subscribed, options: [.specialUse, .recursiveMatch]),
                "(SPECIAL-USE RECURSIVEMATCH SUBSCRIBED)"
            ),
        ]
    )
    func encodeMultipleOptions(_ fixture: EncodeFixture<ListSelectOptions?>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse single option",
        arguments: [
            ParseFixture.listSelectOption("SUBSCRIBED", " ", expected: .success(.subscribed)),
            ParseFixture.listSelectOption("REMOTE", " ", expected: .success(.remote)),
            ParseFixture.listSelectOption("RECURSIVEMATCH", " ", expected: .success(.recursiveMatch)),
            ParseFixture.listSelectOption("SPECIAL-USE", " ", expected: .success(.specialUse)),
            ParseFixture.listSelectOption("MYEXT", expected: .success(.option(.init(key: .standard("MYEXT"), value: nil)))),
            ParseFixture.listSelectOption("(invalid)", "", expected: .failure),
            ParseFixture.listSelectOption("", "", expected: .incompleteMessage),
        ]
    )
    func parseSingleOption(_ fixture: ParseFixture<ListSelectOption>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<ListSelectOption> {
    fileprivate static func listSelectOption(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectOption($1) }
        )
    }
}

extension EncodeFixture<ListSelectOptions?> {
    fileprivate static func listSelectOptions(_ input: T, _ expectedString: String) -> Self {
        Self(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeListSelectOptions($1) }
        )
    }
}

extension ParseFixture<ListSelectOption> {
    fileprivate static func listSelectOption(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseListSelectOption
        )
    }
}
