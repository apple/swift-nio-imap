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

@Suite("IMAPCalendarDay")
struct DateTests {}

extension DateTests {
    @Test func `date initialization`() throws {
        let day = 25
        let month = 6
        let year = 1994
        let date = try #require(IMAPCalendarDay(year: year, month: month, day: day))

        #expect(date.day == day)
        #expect(date.month == month)
        #expect(date.year == year)
    }

    @Test(arguments: [
        EncodeFixture.date(
            IMAPCalendarDay(year: 1994, month: 6, day: 25)!,
            "25-Jun-1994"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2000, month: 1, day: 1)!,
            "1-Jan-2000"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2024, month: 12, day: 31)!,
            "31-Dec-2024"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 1970, month: 1, day: 1)!,
            "1-Jan-1970"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2024, month: 2, day: 29)!,
            "29-Feb-2024"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2025, month: 7, day: 4)!,
            "4-Jul-2025"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 1999, month: 3, day: 15)!,
            "15-Mar-1999"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2010, month: 8, day: 30)!,
            "30-Aug-2010"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2015, month: 11, day: 11)!,
            "11-Nov-2015"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2020, month: 4, day: 1)!,
            "1-Apr-2020"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2018, month: 5, day: 31)!,
            "31-May-2018"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2022, month: 9, day: 9)!,
            "9-Sep-2022"
        ),
        EncodeFixture.date(
            IMAPCalendarDay(year: 2023, month: 10, day: 13)!,
            "13-Oct-2023"
        ),
    ])
    func encode(_ fixture: EncodeFixture<IMAPCalendarDay>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.date("25-Jun-1994", " ", expected: .success(IMAPCalendarDay(year: 1994, month: 6, day: 25)!)),
        ParseFixture.date("\"25-Jun-1994\"", "\r", expected: .success(IMAPCalendarDay(year: 1994, month: 6, day: 25)!)),
        ParseFixture.date("\"25-Jun-1994 ", "\r", expected: .failure),
        ParseFixture.date("\"\"", "\r", expected: .failure),
    ])
    func parse(_ fixture: ParseFixture<IMAPCalendarDay>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<IMAPCalendarDay> {
    fileprivate static func date(
        _ input: IMAPCalendarDay,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeDate($1) }
        )
    }
}

extension ParseFixture<IMAPCalendarDay> {
    fileprivate static func date(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseDate
        )
    }
}
