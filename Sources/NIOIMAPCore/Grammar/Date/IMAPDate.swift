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

import struct NIO.ByteBuffer

/// A calendar day formatted as `dd-MMM-yyyy` as defined in RFC 3501.
///
/// This type represents a date in the IMAP date format, where the month is represented
/// as a three-letter abbreviation (e.g., `Jan`, `Feb`, etc.). This format is used in various
/// IMAP protocol messages including the `INTERNALDATE` message attribute and `APPEND` commands.
///
/// The `IMAPCalendarDay` provides basic validation of date components. Note that the
/// validation checks component ranges but does not validate whether the combination
/// represents a valid calendar date (e.g., February 30 is accepted).
///
/// ### Example
///
/// ```
/// * 1 FETCH (INTERNALDATE "15-Mar-2026 10:30:45 +0000")
/// ```
///
/// The date portion `15-Mar-2026` corresponds to an ``IMAPCalendarDay`` with
/// `year: 2026`, `month: 3`, and `day: 15`.
///
/// - SeeAlso: [RFC 3501 Section 2.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.3)
public struct IMAPCalendarDay: Hashable, Sendable {
    /// The year, constrained to the range `1900...2500`.
    ///
    /// This is a 4-digit year value. The range constraint reflects common IMAP server
    /// implementations which typically support dates in this range.
    public let year: Int

    /// The month, constrained to the range `1...12`.
    ///
    /// Month 1 is January, month 12 is December.
    public let month: Int

    /// The day of the month, constrained to the range `1...31`.
    ///
    /// The range accepts all valid day numbers across different months. No validation
    /// is performed to verify the day is valid for the specific month (e.g., February 30 is accepted).
    public let day: Int

    /// Creates a new `IMAPCalendarDay` and performs basic validation on the input.
    ///
    /// All parameters are validated against their documented ranges. If any parameter
    /// falls outside its valid range, this initializer returns `nil`.
    ///
    /// - Parameters:
    ///   - year: The year, validated to be between 1900 and 2500 inclusive.
    ///   - month: The month, validated to be between 1 and 12 inclusive.
    ///   - day: The day, validated to be between 1 and 31 inclusive. The number of days in the given month is not validated.
    /// - Returns: A new `IMAPCalendarDay` if all validation is passed, otherwise `nil`.
    public init?(year: Int, month: Int, day: Int) {
        guard
            day >= 1,
            day <= 31,
            month >= 1,
            month <= 12,
            year >= 1900,
            year <= 2500
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }
}

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeDate(_ date: IMAPCalendarDay) -> Int {
        self.writeString("\(date.day)-\(date.monthString)-\(date.year)")
    }
}

extension IMAPCalendarDay {
    /// The three-letter month abbreviation for this calendar day.
    ///
    /// Returns the month name as used in the IMAP date format (e.g., `Jan`, `Feb`, `Mar`, etc.).
    fileprivate var monthString: String {
        switch month {
        case 1: return "Jan"
        case 2: return "Feb"
        case 3: return "Mar"
        case 4: return "Apr"
        case 5: return "May"
        case 6: return "Jun"
        case 7: return "Jul"
        case 8: return "Aug"
        case 9: return "Sep"
        case 10: return "Oct"
        case 11: return "Nov"
        case 12: return "Dec"
        default: preconditionFailure("Expected 1 <= month <= 12")
        }
    }

    /// Parses a three-letter month name and returns the corresponding month number.
    ///
    /// The parsing is case-insensitive. For example, both `Jan` and `jan` return `1`.
    ///
    /// - Parameter text: The three-letter month abbreviation.
    /// - Returns: The month number (1-12) if the text matches a valid month name, otherwise `nil`.
    static func month(text: String) -> Int? {
        switch text.lowercased() {
        case "jan": return 1
        case "feb": return 2
        case "mar": return 3
        case "apr": return 4
        case "may": return 5
        case "jun": return 6
        case "jul": return 7
        case "aug": return 8
        case "sep": return 9
        case "oct": return 10
        case "nov": return 11
        case "dec": return 12
        default: return nil
        }
    }
}
