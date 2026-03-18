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
struct OptionValueCompTests {
    @Test(
        "encode",
        arguments: [
            EncodeFixture.optionValueComp(.string("test"), #""test""#),
            EncodeFixture.optionValueComp([.string("test1"), .string("test2")], #"("test1" "test2")"#),
            EncodeFixture.optionValueComp(
                .array([.string("a"), .array([.string("E"), .string("F")]), .string("b")]),
                #"("a" ("E" "F") "b")"#
            ),
        ]
    )
    func encode(_ fixture: EncodeFixture<OptionValueComp>) {
        fixture.checkEncoding()
    }

    @Test(
        "parse",
        arguments: [
            ParseFixture.optionValueComp(#""test""#, expected: .success(.string("test"))),
            ParseFixture.optionValueComp("atom", ")", expected: .success(.string("atom"))),
            ParseFixture.optionValueComp(#"("val")"#, " ", expected: .success(.array([.string("val")]))),
            ParseFixture.optionValueComp("", "", expected: .incompleteMessage),
        ]
    )
    func parse(_ fixture: ParseFixture<OptionValueComp>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<OptionValueComp> {
    fileprivate static func optionValueComp(_ input: OptionValueComp, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeOptionValueComp($1) }
        )
    }
}

extension ParseFixture<OptionValueComp> {
    fileprivate static func optionValueComp(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseOptionValueComp
        )
    }
}
