//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
@testable import IMAPToolLib
import NIOIMAP
import Testing

@Suite("InternetMessageDate parsing")
private enum InternetMessageDateParsingTests {
    // MARK: - Fast path: parseWithoutFoundation

    struct FixedTZParseFixture: Sendable, CustomTestStringConvertible {
        var input: String
        var expected: TimeInterval

        var testDescription: String { input }
    }

    /// Cases that the strptime-based path can parse — that is, dates with a
    /// numeric `±HHMM` offset (or no offset) and no obs-zone abbreviation.
    ///
    /// The `parseWithoutFoundation` fast path is Darwin-only (glibc has no
    /// `strptime_l`), so this test only runs there. The same inputs are covered
    /// through `parse()` — which falls back to Foundation — on all platforms.
    #if canImport(Darwin)
    @Test(arguments: [
        // IMAP-style quoted dates
        FixedTZParseFixture(input: #""29-Jul-2013 11:45:15 -0700""#, expected: 396_816_315),
        FixedTZParseFixture(input: #"" 8-Nov-2004 08:00:00 -0700""#, expected: 121_618_800),
        FixedTZParseFixture(input: #""08-May-1985 15:00:00 +0100""#, expected: -493_898_400),
        FixedTZParseFixture(input: #""4-Nov-1980 14:49:00 -0500""#, expected: -636_091_860),
        // RFC 2822
        FixedTZParseFixture(input: "Tue, 29 Oct 2012 10:00:00 -0800", expected: 373_226_400),
        FixedTZParseFixture(input: "29 Oct 2012 10:00 -0800", expected: 373_226_400),
        FixedTZParseFixture(input: "  Tue,  29  Oct  2012  10:00:00  -0800  ", expected: 373_226_400),
        FixedTZParseFixture(input: "Thu, 1 Apr 1976 17:00:00 -0800", expected: -781_052_400),
        FixedTZParseFixture(input: "Mon, May 20 2002 10:18:51 -0700", expected: 43_607_931),
        // Time zone offset followed by a parenthesised time-zone name (seen in the wild):
        FixedTZParseFixture(input: "Sat, 5 Sep 2020 02:25:49 +0000 (GMT)", expected: 620_965_549),
        FixedTZParseFixture(input: "Fri, 18 Oct 2019 14:03:42 -0700 (PDT)", expected: 593_125_422),
    ])
    static func parsingWithoutFoundation(fixture: FixedTZParseFixture) {
        let date = InternetMessageDate(fixture.input).parseWithoutFoundation()
        expectDate(date, equals: fixture.expected, input: fixture.input)
    }
    #endif

    // MARK: - Empty / unparseable

    @Test(arguments: ["", " \t\n"])
    static func emptyDates(input: String) {
        #expect(InternetMessageDate(input).parse() == nil)
    }

    // MARK: - IMAP calendar-day form

    @Test(arguments: [
        FixedTZParseFixture(input: #""29-Jul-2013 11:45:15 -0700""#, expected: 396_816_315),
        FixedTZParseFixture(input: #"" 8-Nov-2004 08:00:00 -0700""#, expected: 121_618_800),
        FixedTZParseFixture(input: #""08-May-1945 15:00:00 +0100""#, expected: -1_756_202_400),
    ])
    static func imapCalendarDays(fixture: FixedTZParseFixture) {
        let date = InternetMessageDate(fixture.input).parse()
        expectDate(date, equals: fixture.expected, input: fixture.input)
    }

    // MARK: - RFC 2822 dates

    @Test(arguments: [
        FixedTZParseFixture(input: "Tue, 29 Oct 2012 10:00:00 -0800", expected: 373_226_400),
        FixedTZParseFixture(input: "29 Oct 2012 10:00 -0800", expected: 373_226_400),
        FixedTZParseFixture(input: "  Tue,  29  Oct  2012  10:00:00  -0800  ", expected: 373_226_400),
        FixedTZParseFixture(input: "Thu, 1 Apr 1976 17:00:00 -0800", expected: -781_052_400),
    ])
    static func internetMessageDates(fixture: FixedTZParseFixture) {
        let date = InternetMessageDate(fixture.input).parse()
        expectDate(date, equals: fixture.expected, input: fixture.input)
    }

    // MARK: - Obsolete dates (RFC 2822 §4.3 obs-zone, 2-digit years)

    @Test(arguments: [
        // The military time zones from RFC 5322 §4.3 don't work with NSDateFormatter/ICU;
        // they aren't covered here.
        FixedTZParseFixture(input: "24 Mar 2001 12:00:00 UT", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 12:00:00 GMT", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 07:00:00 EST", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 08:00 EDT", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 06:00:00 CST", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 07:00 CDT", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 05:00:00 MST", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 06:00:00 MDT", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 04:00 PST", expected: 7_128_000),
        FixedTZParseFixture(input: "24 Mar 2001 05:00:00 PDT", expected: 7_128_000),
        // 2-digit years before 50 are 20xx; 50 and later are 19xx.
        FixedTZParseFixture(input: "24 Jun 13 10:45 -0700", expected: 393_788_700),
        FixedTZParseFixture(input: "3 Jun 77 01:25 -0500", expected: -744_140_100),
    ])
    static func obsoleteInternetMessageDates(fixture: FixedTZParseFixture) {
        let date = InternetMessageDate(fixture.input).parse()
        expectDate(date, equals: fixture.expected, input: fixture.input)
    }

    // MARK: - Illegal-but-tolerated forms

    @Test
    static func illegalDatesFromICloud() {
        // iCloud's quirky form:
        let date = InternetMessageDate("Sat, 5 Sep 2020 02:25:49 +0000 (GMT)").parse()
        expectDate(date, equals: 620_965_549, input: "iCloud")
    }

    @Test(arguments: [
        FixedTZParseFixture(input: "29-Jul-2013 11:45:15 -0700", expected: 396_816_315),
        FixedTZParseFixture(input: "8-Nov-04 08:00 -0700", expected: 121_618_800),
        FixedTZParseFixture(input: "8-Nov-04 08:00 PDT", expected: 121_618_800),
    ])
    static func illegalIMAPLikeDates(fixture: FixedTZParseFixture) {
        let date = InternetMessageDate(fixture.input).parse()
        expectDate(date, equals: fixture.expected, input: fixture.input)
    }

    @Test(arguments: [
        FixedTZParseFixture(input: "Jun 5, 2011  7:59:47 AM US/Eastern", expected: 328_942_787),
        FixedTZParseFixture(input: "Mon, May 20 2002 10:18:51 -0700", expected: 43_607_931),
        FixedTZParseFixture(input: "January 08, 2004 12:01:13 EST", expected: 95_274_073),
        FixedTZParseFixture(input: "January 27, 2004 11:42:03 EST", expected: 96_914_523),
        FixedTZParseFixture(input: "Tue Oct 21, 2003  15:59:25 US/Eastern", expected: 88_459_165),
        FixedTZParseFixture(input: "Sun, Mar 31, 1996 07:57 EDT", expected: -150_033_780),
        FixedTZParseFixture(input: "December 30, 2003 12:30:43 EST", expected: 94_498_243),
        FixedTZParseFixture(input: "Mon Sep 22, 2003  14:49:00 US/Eastern", expected: 85_949_340),
        FixedTZParseFixture(input: "Fri May 23 12:00:00 EDT", expected: 359_438_400),
        FixedTZParseFixture(input: #""4-Nov-1980 14:49:00 -0500""#, expected: -636_091_860),
        FixedTZParseFixture(input: "1984-5-4 15:00:00 -0700", expected: -525_751_200),
        FixedTZParseFixture(input: "2/9 3:42 AM", expected: -28_250_280),
        FixedTZParseFixture(input: "02/09/87 3:42 am", expected: -438_477_480),
    ])
    static func illegalDates(fixture: FixedTZParseFixture) {
        let date = InternetMessageDate(fixture.input).parse()
        expectDate(date, equals: fixture.expected, input: fixture.input)
    }

    // MARK: - Local-timezone dates (no offset in the string)
    //
    // These dates omit the time-zone, so the parser interprets them in the
    // local time zone. We compute the expected timestamp the same way, which
    // means these tests are sensitive to the test machine's time zone — but
    // also mirror the parser's behavior exactly.

    struct LocalTZParseFixture: Sendable, CustomTestStringConvertible {
        var input: String
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        var second: Int = 0

        var testDescription: String { input }
    }

    @Test(arguments: [
        LocalTZParseFixture(
            input: "Tue, Dec 30, 2008 at 3:22 PM",
            year: 2008,
            month: 12,
            day: 30,
            hour: 15,
            minute: 22
        ),
        LocalTZParseFixture(
            input: "Mon Mar 30 11:45:00 2003",
            year: 2003,
            month: 3,
            day: 30,
            hour: 11,
            minute: 45
        ),
        LocalTZParseFixture(
            input: "Tue, 19 Aug 2003 14:49:00",
            year: 2003,
            month: 8,
            day: 19,
            hour: 14,
            minute: 49
        ),
        LocalTZParseFixture(
            input: "5 Nov 1982 14:49:00",
            year: 1982,
            month: 11,
            day: 5,
            hour: 14,
            minute: 49
        ),
    ])
    static func datesParsedInLocalTimeZone(fixture: LocalTZParseFixture) {
        guard let actual = InternetMessageDate(fixture.input).parse() else {
            Issue.record("Failed to parse '\(fixture.input)'")
            return
        }
        let components = DateComponents(
            year: fixture.year,
            month: fixture.month,
            day: fixture.day,
            hour: fixture.hour,
            minute: fixture.minute,
            second: fixture.second
        )
        let expectedDate = Calendar(identifier: .gregorian).date(from: components)!
        let expected =
            expectedDate.timeIntervalSinceReferenceDate
            + TimeZone.current.daylightSavingTimeOffset(for: expectedDate)
        let actualInterval = actual.timeIntervalSinceReferenceDate
        #expect(
            abs(actualInterval - expected) < 0.000_5,
            "Parsed '\(fixture.input)' as \(actual); expected interval \(expected), got \(actualInterval)"
        )
    }

    // MARK: - Formatting (Date → InternetMessageDate)

    struct FormatFixture: Sendable, CustomTestStringConvertible {
        var date: Date
        var calendar: Calendar
        var calendarLabel: String
        var expected: String

        var testDescription: String { "\(date) / \(calendarLabel)" }
    }

    @Test(arguments: [
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 590_000_000),
            calendar: .testCalendar,
            calendarLabel: "+0700",
            expected: "Thu, 12 Sep 2019 23:53:20 +0700"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 590_012_345),
            calendar: .testCalendar,
            calendarLabel: "+0700",
            expected: "Fri, 13 Sep 2019 03:19:05 +0700"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 590_018_888),
            calendar: .testCalendar,
            calendarLabel: "+0700",
            expected: "Fri, 13 Sep 2019 05:08:08 +0700"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 596_737_019),
            calendar: .testCalendar,
            calendarLabel: "+0700",
            expected: "Fri, 29 Nov 2019 23:16:59 +0700"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 596_737_019),
            calendar: .testCalendarB,
            calendarLabel: "Sao_Paulo",
            expected: "Fri, 29 Nov 2019 13:16:59 -0300"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: -150_033_780),
            calendar: .testCalendar,
            calendarLabel: "+0700",
            expected: "Sun, 31 Mar 1996 18:57:00 +0700"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: -150_033_780),
            calendar: .testCalendarB,
            calendarLabel: "Sao_Paulo",
            expected: "Sun, 31 Mar 1996 08:57:00 -0300"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 88_459_165),
            calendar: .testCalendar,
            calendarLabel: "+0700",
            expected: "Wed, 22 Oct 2003 02:59:25 +0700"
        ),
        FormatFixture(
            date: Date(timeIntervalSinceReferenceDate: 88_459_165),
            calendar: .testCalendarB,
            calendarLabel: "Sao_Paulo",
            expected: "Tue, 21 Oct 2003 17:59:25 -0200"
        ),
    ])
    static func formatAsRFC822(fixture: FormatFixture) {
        let formatted = String(InternetMessageDate(from: fixture.date, calendar: fixture.calendar))
        #expect(formatted == fixture.expected)
    }

    // MARK: - Round trip (format → parse)

    @Test(arguments: [
        Date(timeIntervalSinceReferenceDate: 590_000_000),
        Date(timeIntervalSinceReferenceDate: 596_737_019),
        Date(timeIntervalSinceReferenceDate: -150_033_780),
        Date(timeIntervalSinceReferenceDate: 88_459_165),
        Date(timeIntervalSinceReferenceDate: 0),
        Date(timeIntervalSinceReferenceDate: 1_000_000_000),
    ])
    static func roundTrip(date: Date) {
        for calendar in [Calendar.testCalendar, .testCalendarB, .testCalendarUTC] {
            let formatted = InternetMessageDate(from: date, calendar: calendar)
            guard let parsed = formatted.parse() else {
                Issue.record("Failed to parse '\(String(formatted))'")
                continue
            }
            // The wire format has second precision, so allow up to ~1 second of drift.
            let drift = abs(parsed.timeIntervalSinceReferenceDate - date.timeIntervalSinceReferenceDate)
            #expect(
                drift < 1.1,
                "'\(String(formatted))' round-tripped with \(drift)s drift"
            )
        }
    }
}

// MARK: - Helpers

private func expectDate(
    _ date: Date?,
    equals expectedInterval: TimeInterval,
    input: String,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let date else {
        Issue.record("Failed to parse '\(input)'", sourceLocation: sourceLocation)
        return
    }
    let actual = date.timeIntervalSinceReferenceDate
    #expect(
        abs(actual - expectedInterval) < 0.000_5,
        "Parsed '\(input)' as \(date); expected interval \(expectedInterval), got \(actual)",
        sourceLocation: sourceLocation
    )
}

extension Calendar {
    /// Gregorian calendar fixed at UTC+07:00 (no DST).
    fileprivate static var testCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        return c
    }

    /// Gregorian calendar in `America/Sao_Paulo` — historically observes DST,
    /// which is what we want to exercise the formatter's offset handling.
    fileprivate static var testCalendarB: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        return c
    }

    /// Gregorian calendar fixed at UTC.
    fileprivate static var testCalendarUTC: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
}
