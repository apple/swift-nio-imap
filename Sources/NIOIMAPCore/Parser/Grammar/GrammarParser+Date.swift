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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif os(Windows)
import ucrt
#elseif canImport(Android)
import Android
#else
let badOS = { fatalError("unsupported OS") }()
#endif

extension GrammarParser {
    // date            = date-text / DQUOTE date-text DQUOTE
    func parseDate(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IMAPCalendarDay {
        func parseDateText_quoted(
            buffer: inout ParseInput,
            tracker: StackTracker
        ) throws(ParseFailure) -> IMAPCalendarDay {
            try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.matchFixed("\"")
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed("\"")
                return date
            }
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseDateText(buffer: &b, tracker: t) },
            { b, t throws(ParseFailure) in try parseDateText_quoted(buffer: &b, tracker: t) },
            tracker: tracker
        )
    }

    // date-day        = 1*2DIGIT
    func parseDateDay(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        let (num, size) = try buffer.parseUnsignedInteger(tracker: tracker, leadingZeros: .allowed)
        guard size <= 2 else {
            throw .mismatch(dynamicHint: "Expected 1 or 2 bytes, got \(size)")
        }
        return num
    }

    // date-day-fixed  = (SP DIGIT) / 2DIGIT
    func parseDateDayFixed(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        func parseDateDayFixed_spaced(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
            // According to the RFC, there should be a space here.
            // But some servers (e.g. qq.com) don't include one.
            try buffer.parseOptional(tracker: tracker) { buffer, tracker throws(ParseFailure) in
                try buffer.matchFixed(" ")
            }
            return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 1)
        }

        return try buffer.parseOneOf(
            { b, t throws(ParseFailure) in try parseDateDayFixed_spaced(buffer: &b, tracker: t) },
            parse2Digit,
            tracker: tracker
        )
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    func parseDateMonth(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        let string = try decodeUTF8(parsed)
        guard let month = IMAPCalendarDay.month(text: string.lowercased()) else {
            throw .mismatch(dynamicHint: "No month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    func parseDateText(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> IMAPCalendarDay {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let date = IMAPCalendarDay(year: year, month: month, day: day) else {
                throw .mismatch(dynamicHint: "Invalid date components \(year) \(month) \(day)")
            }
            return date
        }
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    func parseInternalDate(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> ServerMessageDate {
        try buffer.composite(tracker: tracker) { buffer, tracker throws(ParseFailure) in
            try buffer.matchFixed("\"")
            let day = try self.parseDateDayFixed(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(" ")

            // time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed(":")
            let second = try self.parse2Digit(buffer: &buffer, tracker: tracker)

            try buffer.matchFixed(" ")

            func splitZoneMinutes(_ raw: Int) -> Int? {
                guard raw >= 0 else { return nil }
                let minutes = raw % 100
                let hours = (raw - minutes) / 100
                guard minutes <= 60, hour <= 24 else { return nil }
                return hours * 60 + minutes
            }

            // zone            = ("+" / "-") 4DIGIT
            func parseZonePositive(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
                try buffer.matchFixed("+")
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw .mismatch(dynamicHint: "Building TimeZone from \(num) failed")
                }
                return zone
            }

            func parseZoneNegative(buffer: inout ParseInput, tracker: StackTracker) throws(ParseFailure) -> Int {
                try buffer.matchFixed("-")
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw .mismatch(dynamicHint: "Building TimeZone from \(num) failed")
                }
                return -zone
            }

            let zone = try buffer.parseOneOf(
                { b, t throws(ParseFailure) in try parseZonePositive(buffer: &b, tracker: t) },
                { b, t throws(ParseFailure) in try parseZoneNegative(buffer: &b, tracker: t) },
                tracker: tracker
            )

            try buffer.matchFixed("\"")
            guard
                let components = ServerMessageDate.Components(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute,
                    second: second,
                    timeZoneMinutes: zone
                )
            else {
                throw .mismatch("Invalid internal date.")
            }
            return ServerMessageDate(components)
        }
    }
}
