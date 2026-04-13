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

@Suite("SortCriterion")
struct SortCriterionTests {
    @Test(arguments: [
        EncodeFixture.sortCriterion(.arrival, "ARRIVAL"),
        EncodeFixture.sortCriterion(.cc, "CC"),
        EncodeFixture.sortCriterion(.date, "DATE"),
        EncodeFixture.sortCriterion(.from, "FROM"),
        EncodeFixture.sortCriterion(.size, "SIZE"),
        EncodeFixture.sortCriterion(.subject, "SUBJECT"),
        EncodeFixture.sortCriterion(.to, "TO"),
        EncodeFixture.sortCriterion(.displayFrom, "DISPLAYFROM"),
        EncodeFixture.sortCriterion(.displayTo, "DISPLAYTO"),
        EncodeFixture.sortCriterion(.descending(.date), "REVERSE DATE"),
        EncodeFixture.sortCriterion(.descending(.subject), "REVERSE SUBJECT"),
    ])
    func encodeSingle(_ fixture: EncodeFixture<SortCriterion>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        EncodeFixture.sortCriteria([.date], "(DATE)"),
        EncodeFixture.sortCriteria([.date, .subject], "(DATE SUBJECT)"),
        EncodeFixture.sortCriteria([.date, .descending(.subject)], "(DATE REVERSE SUBJECT)"),
        EncodeFixture.sortCriteria([.arrival, .cc, .from], "(ARRIVAL CC FROM)"),
    ])
    func encodeCriteria(_ fixture: EncodeFixture<[SortCriterion]>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.sortCriterion("ARRIVAL", expected: .success(.arrival)),
        ParseFixture.sortCriterion("CC", expected: .success(.cc)),
        ParseFixture.sortCriterion("DATE", expected: .success(.date)),
        ParseFixture.sortCriterion("FROM", expected: .success(.from)),
        ParseFixture.sortCriterion("SIZE", expected: .success(.size)),
        ParseFixture.sortCriterion("SUBJECT", expected: .success(.subject)),
        ParseFixture.sortCriterion("TO", expected: .success(.to)),
        ParseFixture.sortCriterion("DISPLAYFROM", expected: .success(.displayFrom)),
        ParseFixture.sortCriterion("DISPLAYTO", expected: .success(.displayTo)),
        ParseFixture.sortCriterion("REVERSE DATE", expected: .success(.descending(.date))),
        ParseFixture.sortCriterion("REVERSE SUBJECT", expected: .success(.descending(.subject))),
        ParseFixture.sortCriterion("arrival", expected: .success(.arrival)),
        ParseFixture.sortCriterion("date", expected: .success(.date)),
        ParseFixture.sortCriterion("reverse date", expected: .success(.descending(.date))),
    ])
    func parseSingle(_ fixture: ParseFixture<SortCriterion>) {
        fixture.checkParsing()
    }

    @Test(arguments: [
        ParseFixture.sortCriteria("(DATE)", expected: .success([.date])),
        ParseFixture.sortCriteria("(DATE SUBJECT)", expected: .success([.date, .subject])),
        ParseFixture.sortCriteria("(DATE REVERSE SUBJECT)", expected: .success([.date, .descending(.subject)])),
        ParseFixture.sortCriteria("(ARRIVAL CC FROM)", expected: .success([.arrival, .cc, .from])),
    ])
    func parseCriteria(_ fixture: ParseFixture<[SortCriterion]>) {
        fixture.checkParsing()
    }

    @Test
    func parseRejectsDoubleReverse() {
        ParseFixture.sortCriterion("REVERSE REVERSE SUBJECT", expected: .failure).checkParsing()
    }
}

// MARK: -

extension EncodeFixture<SortCriterion> {
    fileprivate static func sortCriterion(
        _ input: SortCriterion,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeSortCriterion($1) }
        )
    }
}

extension EncodeFixture<[SortCriterion]> {
    fileprivate static func sortCriteria(
        _ input: [SortCriterion],
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            expectedString: expectedString,
            encoder: { $0.writeSortCriteria($1) }
        )
    }
}

extension ParseFixture<SortCriterion> {
    fileprivate static func sortCriterion(
        _ input: String,
        _ terminator: String = ")",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSortCriterion
        )
    }
}

extension ParseFixture<[SortCriterion]> {
    fileprivate static func sortCriteria(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseSortCriteria
        )
    }
}
