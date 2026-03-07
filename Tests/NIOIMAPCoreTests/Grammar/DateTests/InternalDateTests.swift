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

@testable import NIOIMAPCore
import Testing

@Suite("ServerMessageDate")
struct InternalDateTests {
    @Test("UInt64 conversion")
    func uint64Conversion() {
        let components = ServerMessageDate.Components(
            year: 2024,
            month: 3,
            day: 15,
            hour: 10,
            minute: 30,
            second: 45,
            timeZoneMinutes: 0
        )!
        let date = ServerMessageDate(components)
        let raw = UInt64(date)
        #expect(raw == date.rawValue)
    }

    @Test("component initialization and roundtrip with typical values")
    func componentInitializationAndRoundtripWithTypicalValues() {
        let components = ServerMessageDate.Components(
            year: 1994,
            month: 6,
            day: 25,
            hour: 1,
            minute: 2,
            second: 3,
            timeZoneMinutes: 620
        )!
        let date = ServerMessageDate(components)
        let c = date.components
        #expect(c.year == 1994)
        #expect(c.month == 6)
        #expect(c.day == 25)
        #expect(c.hour == 1)
        #expect(c.minute == 2)
        #expect(c.second == 3)
        #expect(c.zoneMinutes == 620)
        #expect(String(reflecting: date) == #""25-Jun-1994 01:02:03 +1020""#)
    }

    @Test("component initialization with minimum boundary values")
    func componentInitializationWithMinimumBoundaryValues() {
        let components = ServerMessageDate.Components(
            year: 1900,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            timeZoneMinutes: -959
        )!
        let date = ServerMessageDate(components)
        let c = date.components
        #expect(c.year == 1900)
        #expect(c.month == 1)
        #expect(c.day == 1)
        #expect(c.hour == 0)
        #expect(c.minute == 0)
        #expect(c.second == 0)
        #expect(c.zoneMinutes == -959)
        #expect(String(reflecting: date) == #""1-Jan-1900 00:00:00 -1559""#)
    }

    @Test("component initialization with maximum boundary values")
    func componentInitializationWithMaximumBoundaryValues() {
        let components = ServerMessageDate.Components(
            year: 2579,
            month: 12,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            timeZoneMinutes: 959
        )!
        let date = ServerMessageDate(components)
        let c = date.components
        #expect(c.year == 2579)
        #expect(c.month == 12)
        #expect(c.day == 31)
        #expect(c.hour == 23)
        #expect(c.minute == 59)
        #expect(c.second == 59)
        #expect(c.zoneMinutes == 959)
        #expect(String(reflecting: date) == #""31-Dec-2579 23:59:59 +1559""#)
    }

    @Test(arguments: [
        ParseFixture.internalDate(
            #""25-Jun-1994 01:02:03 +1020""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 1994,
                        month: 6,
                        day: 25,
                        hour: 1,
                        minute: 2,
                        second: 3,
                        timeZoneMinutes: 620
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""01-Jan-1900 00:00:00 -1559""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 1900,
                        month: 1,
                        day: 1,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: -959
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""31-Dec-2579 23:59:59 +1559""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2579,
                        month: 12,
                        day: 31,
                        hour: 23,
                        minute: 59,
                        second: 59,
                        timeZoneMinutes: 959
                    )!
                )
            )
        ),
        ParseFixture.internalDate(#""25-Jun-1994 01"#, "", expected: .incompleteMessageIgnoringBufferModifications),
        ParseFixture.internalDate(#""25-Jun-199401:02:03+1020""#, "", expected: .failureIgnoringBufferModifications),
        ParseFixture.internalDate(
            #""25-Jun-1994 01:02:03 +12345678\n""#,
            "",
            expected: .failureIgnoringBufferModifications
        ),
        ParseFixture.internalDate(#""25-Jun-1994 01:02:03 +12""#, "", expected: .failureIgnoringBufferModifications),
        ParseFixture.internalDate(#""25-Jun-1994 01:02:03 abc""#, "", expected: .failureIgnoringBufferModifications),
        ParseFixture.internalDate(
            #"" 5-Jun-1994 01:02:03 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 1994,
                        month: 6,
                        day: 5,
                        hour: 1,
                        minute: 2,
                        second: 3,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""99-Jun-1994 01:02:03 +0000""#,
            "\r",
            expected: .failureIgnoringBufferModifications
        ),
        ParseFixture.internalDate(
            #""25-Jun-1994 01:02:03 +9999""#,
            "\r",
            expected: .failureIgnoringBufferModifications
        ),
        ParseFixture.internalDate(
            #""25-Jun-1994 01:02:03 -9999""#,
            "\r",
            expected: .failureIgnoringBufferModifications
        ),
        ParseFixture.internalDate(
            #""15-Feb-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 2,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Mar-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 3,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Apr-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 4,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-May-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 5,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Jul-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 7,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Aug-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 8,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Sep-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 9,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Oct-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 10,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
        ParseFixture.internalDate(
            #""15-Nov-2000 00:00:00 +0000""#,
            "\r",
            expected: .success(
                ServerMessageDate(
                    ServerMessageDate.Components(
                        year: 2000,
                        month: 11,
                        day: 15,
                        hour: 0,
                        minute: 0,
                        second: 0,
                        timeZoneMinutes: 0
                    )!
                )
            )
        ),
    ])
    func parse(_ fixture: ParseFixture<ServerMessageDate>) {
        fixture.checkParsing()
    }

    @Test(
        "encodes all month names",
        arguments: [
            (1, "Jan"), (2, "Feb"), (3, "Mar"), (4, "Apr"), (5, "May"),
            (7, "Jul"), (8, "Aug"), (9, "Sep"), (10, "Oct"), (11, "Nov"), (12, "Dec"),
        ] as [(Int, String)]
    )
    func encodesMonthName(_ fixture: (Int, String)) {
        let (month, monthName) = fixture
        let components = ServerMessageDate.Components(
            year: 2000,
            month: month,
            day: 15,
            hour: 12,
            minute: 0,
            second: 0,
            timeZoneMinutes: 0
        )!
        let date = ServerMessageDate(components)
        #expect(String(reflecting: date) == "\"15-\(monthName)-2000 12:00:00 +0000\"")
    }
}

// MARK: -

extension ParseFixture<ServerMessageDate> {
    fileprivate static func internalDate(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseInternalDate
        )
    }
}
