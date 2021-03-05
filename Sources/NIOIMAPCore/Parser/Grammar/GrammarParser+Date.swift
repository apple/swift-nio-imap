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

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Darwin
#elseif os(Linux) || os(FreeBSD) || os(Android)
import Glibc
#else
let badOS = { fatalError("unsupported OS") }()
#endif

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

extension GrammarParser {
    // date            = date-text / DQUOTE date-text DQUOTE
    static func parseDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPDate {
        func parseDateText_quoted(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPDate {
            try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
                try ParserLibrary.fixedString("\"", buffer: &buffer, tracker: tracker)
                let date = try self.parseDateText(buffer: &buffer, tracker: tracker)
                try ParserLibrary.fixedString("\"", buffer: &buffer, tracker: tracker)
                return date
            }
        }

        return try ParserLibrary.oneOf([
            parseDateText,
            parseDateText_quoted,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-day        = 1*2DIGIT
    static func parseDateDay(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let (num, size) = try ParserLibrary.parseUnsignedInteger(buffer: &buffer, tracker: tracker, allowLeadingZeros: true)
        guard size <= 2 else {
            throw ParserError(hint: "Expected 1 or 2 bytes, got \(size)")
        }
        return num
    }

    // date-day-fixed  = (SP DIGIT) / 2DIGIT
    static func parseDateDayFixed(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        func parseDateDayFixed_spaced(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
            try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)
            return try self.parseNDigits(buffer: &buffer, tracker: tracker, bytes: 1)
        }

        return try ParserLibrary.oneOf([
            parseDateDayFixed_spaced,
            parse2Digit,
        ], buffer: &buffer, tracker: tracker)
    }

    // date-month      = "Jan" / "Feb" / "Mar" / "Apr" / "May" / "Jun" /
    //                   "Jul" / "Aug" / "Sep" / "Oct" / "Nov" / "Dec"
    static func parseDateMonth(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
        let string = try ParserLibrary.parseOneOrMoreCharacters(buffer: &buffer, tracker: tracker) { char -> Bool in
            isalnum(Int32(char)) != 0
        }
        guard let month = IMAPDate.month(text: string.lowercased()) else {
            throw ParserError(hint: "No month match for \(string)")
        }
        return month
    }

    // date-text       = date-day "-" date-month "-" date-year
    static func parseDateText(buffer: inout ParseBuffer, tracker: StackTracker) throws -> IMAPDate {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            let day = try self.parseDateDay(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            guard let date = IMAPDate(year: year, month: month, day: day) else {
                throw ParserError(hint: "Invalid date components \(year) \(month) \(day)")
            }
            return date
        }
    }

    // date-time       = DQUOTE date-day-fixed "-" date-month "-" date-year
    //                   SP time SP zone DQUOTE
    static func parseInternalDate(buffer: inout ParseBuffer, tracker: StackTracker) throws -> InternalDate {
        try ParserLibrary.composite(buffer: &buffer, tracker: tracker) { buffer, tracker in
            try ParserLibrary.fixedString("\"", buffer: &buffer, tracker: tracker)
            let day = try self.parseDateDayFixed(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString("-", buffer: &buffer, tracker: tracker)
            let month = try self.parseDateMonth(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString("-", buffer: &buffer, tracker: tracker)
            let year = try self.parse4Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)

            // time            = 2DIGIT ":" 2DIGIT ":" 2DIGIT
            let hour = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(":", buffer: &buffer, tracker: tracker)
            let minute = try self.parse2Digit(buffer: &buffer, tracker: tracker)
            try ParserLibrary.fixedString(":", buffer: &buffer, tracker: tracker)
            let second = try self.parse2Digit(buffer: &buffer, tracker: tracker)

            try ParserLibrary.fixedString(" ", buffer: &buffer, tracker: tracker)

            func splitZoneMinutes(_ raw: Int) -> Int? {
                guard raw >= 0 else { return nil }
                let minutes = raw % 100
                let hours = (raw - minutes) / 100
                guard minutes <= 60, hour <= 24 else { return nil }
                return hours * 60 + minutes
            }

            // zone            = ("+" / "-") 4DIGIT
            func parseZonePositive(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
                try ParserLibrary.fixedString("+", buffer: &buffer, tracker: tracker)
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return zone
            }

            func parseZoneNegative(buffer: inout ParseBuffer, tracker: StackTracker) throws -> Int {
                try ParserLibrary.fixedString("-", buffer: &buffer, tracker: tracker)
                let num = try self.parse4Digit(buffer: &buffer, tracker: tracker)
                guard let zone = splitZoneMinutes(num) else {
                    throw ParserError(hint: "Building TimeZone from \(num) failed")
                }
                return -zone
            }

            let zone = try ParserLibrary.oneOf([
                parseZonePositive,
                parseZoneNegative,
            ], buffer: &buffer, tracker: tracker)

            try ParserLibrary.fixedString("\"", buffer: &buffer, tracker: tracker)
            guard
                let components = InternalDate.Components(year: year, month: month, day: day, hour: hour, minute: minute, second: second, timeZoneMinutes: zone)
            else {
                throw ParserError(hint: "Invalid internal date.")
            }
            return InternalDate(components)
        }
    }
}
