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

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

extension GrammarParser {
    // date            = date-text / DQUOTE date-text DQUOTE
    func parseDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPCalendarDay {
        func parseDateText_quoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPCalendarDay {
            try buffer.composite(tracker: tracker) { buffer, tracker in
                try buffer.matchFixed("\"")
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try buffer.matchFixed("\"")
                return date
            }
        }

        return try buffer.parseOneOf(
            { try parseDateText(buffer: &$0, tracker: $1) },
            { try parseDateText_quoted(buffer: &$0, tracker: $1) },
            tracker: tracker
        )
    }

    // date-day        = 1*2DIGIT
    func parseDateDay(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let (num, size) = try buffer.parseUnsignedInteger(tracker: tracker, leadingZeros: .allowed)
        guard size <= 2 else {
            throw ParserError(hint: "Expected 1 or 2 bytes, got \(size)")
        }
        return num
    }

    // date-day-fixed  = (SP DIGIT) / 2DIGIT
    func parseDateDayFixed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        func parseDateDayFixed_spaced(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
            // According to the RFC, there should be a space here.
            // But some servers (e.g. qq.com) don't include one.
            try buffer.parseOptional(tracker: tracker) { buffer, tracker in
                try buffer.matchFixed(" ")
            }
            return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 1)
        }

        return try buffer.parseOneOf(
            { try parseDateDayFixed_spaced(buffer: &$0, tracker: $1) },
            parse2Digit,
            tracker: tracker
        )
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    func parseDateMonth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let parsed = try buffer.parseOneOrMoreCharacters { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        let string = try decodeUTF8(parsed)
        guard let month = IMAPCalendarDay.month(text: string.lowercased()) else {
            throw ParserError(hint: "No month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    func parseDateText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPCalendarDay {
        try buffer.composite(tracker: tracker) { buffer, tracker in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try buffer.matchFixed("-")
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let date = IMAPCalendarDay(year: year, month: month, day: day) else {
                throw ParserError(hint: "Invalid date components \(year) \(month) \(day)")
            }
            return date
        }
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    func parseInternalDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> ServerMessageDate {
        try buffer.composite(tracker: tracker) { buffer, tracker in
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
            func parseZonePositive(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
                try buffer.matchFixed("+")
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return zone
            }

            func parseZoneNegative(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
                try buffer.matchFixed("-")
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return -zone
            }

            let zone = try buffer.parseOneOf(
                { try parseZonePositive(buffer: &$0, tracker: $1) },
                { try parseZoneNegative(buffer: &$0, tracker: $1) },
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
                throw ParserError(hint: "Invalid internal date.")
            }
            return ServerMessageDate(components)
        }
    }
}
