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

/// A complete date and time value in RFC 3339 format with an optional fraction-of-second.
///
/// This type represents a full date-time specification as defined in RFC 3339, combining
/// a ``FullDate`` and ``FullTime`` into a single value. RFC 3339 is used in IMAP extensions
/// such as NOTIFY (RFC 5465) and METADATA (RFC 5464) for precise timestamp representation.
///
/// The format when encoded is `YYYY-MM-DDTHH:MM:SS[.FRACTION]` where the `T` separates the
/// date and time components.
///
/// ### Example
///
/// ```
/// "2026-03-15T10:30:45"
/// "2026-03-15T10:30:45.123"
/// ```
///
/// These examples correspond to ``FullDateTime`` values combining a ``FullDate``
/// (2026-03-15) with ``FullTime`` values (10:30:45 with optional fraction).
///
/// - SeeAlso: [RFC 3339](https://datatracker.ietf.org/doc/html/rfc3339)
public struct FullDateTime: Hashable, Sendable {
    /// The date component of this date-time value.
    ///
    /// The date contains the year, month, and day values.
    public var date: FullDate

    /// The time component of this date-time value.
    ///
    /// The time contains the hour, minute, second, and optional fraction values.
    public var time: FullTime

    /// Creates a new `FullDateTime`.
    ///
    /// - Parameters:
    ///   - date: The date component.
    ///   - time: The time component.
    public init(date: FullDate, time: FullTime) {
        self.date = date
        self.time = time
    }
}

/// A calendar date in RFC 3339 format (`YYYY-MM-DD`).
///
/// This type represents a date value as defined in RFC 3339, containing year, month, and day
/// components. It is used in combination with ``FullTime`` to form a complete ``FullDateTime``.
///
/// The initializer uses `precondition` to verify month and day are within valid ranges but does
/// not validate whether the day is appropriate for the given month (e.g., February 30 is accepted).
public struct FullDate: Hashable, Sendable {
    /// The year as any non-negative integer.
    ///
    /// RFC 3339 allows any non-negative integer for the year, though practical applications
    /// typically use 4-digit year values.
    public let year: Int

    /// The month in the range `1...12`.
    ///
    /// Month 1 is January, month 12 is December.
    public let month: Int

    /// The day in the range `1...31`.
    ///
    /// The range accepts all valid day numbers. No validation is performed to verify
    /// the day is valid for the specific month (e.g., February 30 is accepted).
    public let day: Int

    /// Creates a new `FullDate`.
    ///
    /// This initializer validates that month is in the range `1...12` and day is in the
    /// range `1...31` using `precondition`. The year can be any non-negative integer.
    ///
    /// - Parameters:
    ///   - year: The year. Any non-negative integer.
    ///   - month: The month in the range `1...12`.
    ///   - day: The day in the range `1...31`.
    public init(year: Int, month: Int, day: Int) {
        precondition(month > 0 && month < 13, "\(month) is not a valid month")
        precondition(day > 0 && day < 32, "\(day) is not a valid day")
        self.year = year
        self.month = month
        self.day = day
    }
}

/// A time of day in RFC 3339 format (`HH:MM:SS[.FRACTION]`).
///
/// This type represents a time value as defined in RFC 3339, containing hour, minute, second,
/// and an optional fractional-second component. It is used in combination with ``FullDate``
/// to form a complete ``FullDateTime``.
///
/// The fractional-second field is partially dynamic: the integer value you provide is written
/// directly to the output. For example, providing `123` writes `.123` and providing `1234`
/// writes `.1234`.
public struct FullTime: Hashable, Sendable {
    /// The hour of the day, 0-based in the range `0...23`.
    ///
    /// Hour 0 is midnight, hour 23 is 11 PM.
    public var hour: Int

    /// The minute of the hour, 0-based in the range `0...59`.
    public var minute: Int

    /// The second of the minute, 0-based in the range `0...59`.
    public var second: Int

    /// The fractional-second component, or `nil` if not included.
    ///
    /// This is a partially-dynamic field and does not directly represent milliseconds,
    /// microseconds, or any specific fractional unit. The number you provide is the number
    /// that will be written directly to the output. For example:
    /// - `123` encodes as `HH:MM:SS.123`
    /// - `1234` encodes as `HH:MM:SS.1234`
    /// - `nil` encodes as `HH:MM:SS` (no fraction)
    public var fraction: Int?

    /// Creates a new `FullTime`.
    ///
    /// Currently no validation of the component values is performed. The caller is responsible
    /// for ensuring the values are in appropriate ranges.
    ///
    /// - Parameters:
    ///   - hour: The hour. 0-based in the range `0...23`.
    ///   - minute: The minute. 0-based in the range `0...59`.
    ///   - second: The second. 0-based in the range `0...59`.
    ///   - fraction: The fractional-second component (optional). Written directly as provided.
    public init(hour: Int, minute: Int, second: Int, fraction: Int? = nil) {
        self.hour = hour
        self.minute = minute
        self.second = second
        self.fraction = fraction
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFullDateTime(_ data: FullDateTime) -> Int {
        self.writeFullDate(data.date) + self.writeString("T") + self.writeFullTime(data.time)
    }

    @discardableResult mutating func writeFullDate(_ data: FullDate) -> Int {
        let year = self.padInteger(data.year, minimum: 4)
        let month = self.padInteger(data.month, minimum: 2)
        let day = self.padInteger(data.day, minimum: 2)
        return self.writeString("\(year)-\(month)-\(day)")
    }

    @discardableResult mutating func writeFullTime(_ data: FullTime) -> Int {
        let hour = self.padInteger(data.hour, minimum: 2)
        let minute = self.padInteger(data.minute, minimum: 2)
        let second = self.padInteger(data.second, minimum: 2)
        return self.writeString("\(hour):\(minute):\(second)")
            + self.writeIfExists(data.fraction) { fraction in
                self.writeString(".\(fraction)")
            }
    }

    func padInteger(_ int: Int, minimum: Int) -> String {
        let short = "\(int)"
        guard short.count < minimum else {
            return short
        }
        return String(repeating: "0", count: (minimum - short.count)) + short
    }
}
