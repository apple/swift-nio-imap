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

@Suite("OptionValueComp")
struct OptionValueTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.optionValue(.string("test"), #"("test")"#),
            EncodeFixture.optionValue(.array([.string("a"), .string("b")]), #"(("a" "b"))"#),
            EncodeFixture.optionValue(
                .array([.string("a"), .array([.string("E"), .string("F")]), .string("b")]),
                #"(("a" ("E" "F") "b"))"#
            ),
        ]
    )
    func encode(_ fixture: EncodeFixture<OptionValueComp>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.optionValue(#"("test")"#, ")", expected: .success(.string("test"))),
            ParseFixture.optionValue("(atom)", ")", expected: .success(.string("atom"))),
            ParseFixture.optionValue("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<OptionValueComp>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<OptionValueComp> {
    fileprivate static func optionValue(_ input: OptionValueComp, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeOptionValue($1) }
        )
    }
}

extension ParseFixture<OptionValueComp> {
    fileprivate static func optionValue(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseOptionValue
        )
    }
}
