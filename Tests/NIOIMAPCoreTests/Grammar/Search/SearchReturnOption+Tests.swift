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

@Suite("SearchReturnOption")
struct SearchReturnOptionTests {
    @Test(arguments: [
        EncodeFixture.searchReturnOption(.min, "MIN"),
        EncodeFixture.searchReturnOption(.max, "MAX"),
        EncodeFixture.searchReturnOption(.all, "ALL"),
        EncodeFixture.searchReturnOption(.count, "COUNT"),
        EncodeFixture.searchReturnOption(.save, "SAVE"),
        EncodeFixture.searchReturnOption(.optionExtension(.init(key: "modifier", value: nil)), "modifier"),
        EncodeFixture.searchReturnOption(.partial(.first(23_500...24_000)), "PARTIAL 23500:24000"),
        EncodeFixture.searchReturnOption(.partial(.last(1...100)), "PARTIAL -1:-100"),
    ])
    func encode(_ fixture: EncodeFixture<SearchReturnOption>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.searchReturnOptions([], ""),
        EncodeFixture.searchReturnOptions([.min], " RETURN (MIN)"),
        EncodeFixture.searchReturnOptions([.all], " RETURN (ALL)"),
        EncodeFixture.searchReturnOptions([.min, .all], " RETURN (MIN ALL)"),
        EncodeFixture.searchReturnOptions([.min, .max, .count], " RETURN (MIN MAX COUNT)"),
        EncodeFixture.searchReturnOptions([.min, .partial(.last(400...1_000))], " RETURN (MIN PARTIAL -400:-1000)"),
    ])
    func `encode multiple`(_ fixture: EncodeFixture<[SearchReturnOption]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.searchReturnOption("MIN", expected: .success(.min)),
        ParseFixture.searchReturnOption("min", expected: .success(.min)),
        ParseFixture.searchReturnOption("mIn", expected: .success(.min)),
        ParseFixture.searchReturnOption("MAX", expected: .success(.max)),
        ParseFixture.searchReturnOption("max", expected: .success(.max)),
        ParseFixture.searchReturnOption("mAx", expected: .success(.max)),
        ParseFixture.searchReturnOption("ALL", expected: .success(.all)),
        ParseFixture.searchReturnOption("all", expected: .success(.all)),
        ParseFixture.searchReturnOption("AlL", expected: .success(.all)),
        ParseFixture.searchReturnOption("COUNT", expected: .success(.count)),
        ParseFixture.searchReturnOption("count", expected: .success(.count)),
        ParseFixture.searchReturnOption("COunt", expected: .success(.count)),
        ParseFixture.searchReturnOption("SAVE", expected: .success(.save)),
        ParseFixture.searchReturnOption("save", expected: .success(.save)),
        ParseFixture.searchReturnOption("saVE", expected: .success(.save)),
        ParseFixture.searchReturnOption("PARTIAL 23500:24000", expected: .success(.partial(.first(23_500...24_000)))),
        ParseFixture.searchReturnOption("partial -1:-100", expected: .success(.partial(.last(1...100)))),
        ParseFixture.searchReturnOption("modifier", expected: .success(.optionExtension(.init(key: "modifier", value: nil)))),
    ])
    func parse(_ fixture: ParseFixture<SearchReturnOption>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.searchReturnOptions(" RETURN (ALL)", expected: .success([.all])),
        ParseFixture.searchReturnOptions(" RETURN (MIN MAX COUNT)", expected: .success([.min, .max, .count])),
        ParseFixture.searchReturnOptions(
            " RETURN (m1 m2)",
            expected: .success([
                .optionExtension(.init(key: "m1", value: nil)),
                .optionExtension(.init(key: "m2", value: nil)),
            ])
        ),
        ParseFixture.searchReturnOptions(" RETURN (PARTIAL 23500:24000)", expected: .success([.partial(.first(23_500...24_000))])),
        ParseFixture.searchReturnOptions(" RETURN (MIN PARTIAL -1:-100 MAX)", expected: .success([.min, .partial(.last(1...100)), .max])),
    ])
    func `parse multiple`(_ fixture: ParseFixture<[SearchReturnOption]>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SearchReturnOption> {
    fileprivate static func searchReturnOption(_ input: SearchReturnOption, _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeSearchReturnOption($1) })
    }
}

extension EncodeFixture<[SearchReturnOption]> {
    fileprivate static func searchReturnOptions(_ input: [SearchReturnOption], _ expectedString: String) -> Self {
        EncodeFixture(input: input, bufferKind: .defaultServer, expectedString: expectedString, encoder: { $0.writeSearchReturnOptions($1) })
    }
}

extension ParseFixture<SearchReturnOption> {
    fileprivate static func searchReturnOption(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSearchReturnOption
        )
    }
}

extension ParseFixture<[SearchReturnOption]> {
    fileprivate static func searchReturnOptions(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSearchReturnOptions
        )
    }
}
