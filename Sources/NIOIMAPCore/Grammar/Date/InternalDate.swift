//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020-2022 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// The internal date and time of a message as stored on the server.
///
/// This type represents the server's record of when a message was received or stored,
/// not the date from the message's headers (which is represented by ``InternetMessageDate``).
/// The internal date consists of a calendar date, time of day, and timezone offset.
///
/// The value is stored as a compact `UInt64` that encodes all components, allowing
/// efficient storage and comparison. Use the ``components`` property or the ``Components``
/// initializer to work with individual date/time components.
///
/// ### Example
///
/// ```
/// * 1 FETCH (INTERNALDATE “15-Mar-2026 10:30:45 +0100”)
/// ```
///
/// This response indicates the message was received on March 15, 2026 at 10:30:45 AM
/// in the UTC+01:00 timezone. This is wrapped as ``ServerMessageDate`` with components
/// accessible via the ``components`` property.
///
/// - SeeAlso: [RFC 3501 Section 2.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.3)
public struct ServerMessageDate: Hashable, Sendable {
    let rawValue: UInt64

    /// The individual date and time components for this internal date.
    ///
    /// This computed property extracts the encoded date, time, and timezone components
    /// from the compact internal representation. The components can be used to
    /// display or work with individual date and time fields.
    ///
    /// - Returns: A ``Components`` structure containing the decoded date, time, and timezone offset.
    public var components: Components {
        var remainder = self.rawValue

        func take(_ a: UInt64) -> Int {
            let r = remainder % (a + 1)
            remainder /= (a + 1)
            return Int(r)
        }

        let day = take(31)
        let month = take(12)
        let hour = take(60)
        let minute = take(60)
        let second = take(60)
        let zoneValue = take(24 * 60)
        let zoneIsNegative = take(2)
        let year = take(UInt64(UInt16.max - 1))
        let zoneMinutes = Int(zoneValue) * ((zoneIsNegative == 0) ? 1 : -1)

        // safe to bang as we can't have an invalid `ServerMessageDate`
        return Components(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second,
            timeZoneMinutes: zoneMinutes
        )!
    }

    public init(
        _ rawValue: UInt64
    ) {
        self.rawValue = rawValue
    }

    /// Creates a new `ServerMessageDate` from individual date and time components.
    ///
    /// This initializer constructs a ``ServerMessageDate`` by encoding the provided
    /// components into the compact rawValue representation.
    ///
    /// - Parameter components: A ``Components`` structure containing the date, time, and timezone information.
    public init(_ components: Components) {
        var rawValue = 0 as UInt64

        func store<A: UnsignedInteger>(_ value: A, _ a: A) {
            rawValue *= UInt64(a + 1)
            rawValue += UInt64(value)
        }

        store(UInt16(components.year), 1)
        store(UInt8(components.zoneMinutes < 0 ? 1 : 0), 2)
        store(UInt16(abs(components.zoneMinutes)), 24 * 60)
        store(UInt8(components.second), 60)
        store(UInt8(components.minute), 60)
        store(UInt8(components.hour), 60)
        store(UInt8(components.month), 12)
        store(UInt8(components.day), 31)

        self.init(rawValue)
    }
}

extension UInt64 {
    public init(_ other: ServerMessageDate) {
        self = other.rawValue
    }
}

extension ServerMessageDate: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeInternalDate(self)
        }
    }
}

extension ServerMessageDate {
    /// Individual date and time components that can be encoded into or extracted from a ``ServerMessageDate``.
    ///
    /// The `Components` structure represents a complete internal date/time value with all components
    /// broken out into separate fields. You can use this type to construct a ``ServerMessageDate``
    /// or to inspect the individual components of an existing one.
    ///
    /// ### Example
    ///
    /// ```
    /// let components = ServerMessageDate.Components(
    ///     year: 2026, month: 3, day: 15,
    ///     hour: 10, minute: 30, second: 45,
    ///     timeZoneMinutes: 60
    /// )
    /// let date = ServerMessageDate(components)
    /// ```
    ///
    /// This creates an ``ServerMessageDate`` representing March 15, 2026 at 10:30:45 UTC+01:00.
    public struct Components: Sendable {
        /// The year, typically represented as a 4-digit integer.
        ///
        /// This is a full year value (e.g., 2026), constrained to fit within an unsigned 16-bit integer.
        public let year: Int

        /// The month, typically represented as a 2-digit integer in the range `1...12`.
        ///
        /// Month 1 is January, month 12 is December.
        public let month: Int

        /// The day of the month, typically represented as a 2-digit integer in the range `1...31`.
        public let day: Int

        /// The hour of the day, typically represented as a 2-digit integer in the range `0...23`.
        ///
        /// Hour 0 is midnight, hour 23 is 11 PM.
        public let hour: Int

        /// The minute of the hour, typically represented as a 2-digit integer in the range `0...59`.
        public let minute: Int

        /// The second of the minute, typically represented as a 2-digit integer in the range `0...60`.
        ///
        /// The range includes 60 to account for leap seconds.
        public let second: Int

        /// Time zone offset in minutes from UTC.
        ///
        /// Positive values indicate east of UTC (ahead of UTC), negative values indicate west of UTC (behind UTC).
        /// For example, +0100 (UTC+01:00) is represented as `60`, and -0500 (UTC-05:00) is represented as `-300`.
        public let zoneMinutes: Int

        /// Creates a new `Components` structure from the given parameters.
        ///
        /// All parameters are validated against their documented ranges. If any parameter
        /// falls outside its valid range, this initializer returns `nil`.
        ///
        /// - Parameters:
        ///   - year: The year, validated to be in the range `1...UInt16.max`.
        ///   - month: The month, validated to be in the range `1...12`.
        ///   - day: The day, validated to be in the range `1...31`.
        ///   - hour: The hour, validated to be in the range `0...23`.
        ///   - minute: The minute, validated to be in the range `0...59`.
        ///   - second: The second, validated to be in the range `0...60` (accounting for leap seconds).
        ///   - timeZoneMinutes: The timezone offset in minutes, validated to be in the range `(-24*60)...(24*60)`.
        /// - Returns: A new `Components` if all validation is passed, otherwise `nil`.
        public init?(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, timeZoneMinutes: Int) {
            guard
                (1...31).contains(day),
                (1...12).contains(month),
                (0...23).contains(hour),
                (0...59).contains(minute),
                (0...60).contains(second),
                ((-24 * 60)...(24 * 60)).contains(timeZoneMinutes),
                (1...Int(UInt16.max)).contains(year)
            else {
                return nil
            }

            self.year = year
            self.month = month
            self.day = day
            self.hour = hour
            self.minute = minute
            self.second = second
            self.zoneMinutes = timeZoneMinutes
        }
    }
}

// MARK: - Internal

extension ServerMessageDate {
    fileprivate func makeParts() -> (Date, Time, TimeZone) {
        let c = self.components
        return (
            Date(year: c.year, month: c.month, day: c.day),
            Time(hour: c.hour, minute: c.minute, second: c.second),
            TimeZone(minutes: c.zoneMinutes)
        )
    }

    fileprivate struct Date {
        var year: Int
        var month: Int
        var day: Int
    }

    fileprivate struct Time: Hashable {
        var hour: Int
        var minute: Int
        var second: Int
    }

    fileprivate struct TimeZone: Hashable {
        var minutes: Int
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInternalDate(_ date: ServerMessageDate) -> Int {
        let p = date.makeParts()

        let monthName: String
        switch p.0.month {
        case 1: monthName = "Jan"
        case 2: monthName = "Feb"
        case 3: monthName = "Mar"
        case 4: monthName = "Apr"
        case 5: monthName = "May"
        case 6: monthName = "Jun"
        case 7: monthName = "Jul"
        case 8: monthName = "Aug"
        case 9: monthName = "Sep"
        case 10: monthName = "Oct"
        case 11: monthName = "Nov"
        case 12: monthName = "Dec"
        default: preconditionFailure("Expected 1 <= month <= 12")
        }

        return
            self.writeString("\"\(p.0.day)-\(monthName)-\(p.0.year) ") + self.writeTime(p.1) + self.writeSpace()
            + self.writeTimezone(p.2) + self.writeString("\"")
    }
}

extension EncodeBuffer {
    @discardableResult private mutating func writeTime(_ time: ServerMessageDate.Time) -> Int {
        let hour = time.hour < 10 ? "0\(time.hour)" : "\(time.hour)"
        let minute = time.minute < 10 ? "0\(time.minute)" : "\(time.minute)"
        let second = time.second < 10 ? "0\(time.second)" : "\(time.second)"
        return self.writeString("\(hour):\(minute):\(second)")
    }
}

extension EncodeBuffer {
    @discardableResult private mutating func writeTimezone(_ timezone: ServerMessageDate.TimeZone) -> Int {
        let value = abs(timezone.minutes)
        let minutes = value % 60
        let hours = (value - minutes) / 60
        let string = String(hours * 100 + minutes)

        let zeroedString: String
        if string.count < 4 {
            var output = ""
            output.reserveCapacity(4)
            output.append(contentsOf: String(repeating: "0", count: 4 - string.count))
            output.append(string)
            zeroedString = output
        } else {
            zeroedString = string
        }

        let modifier = (timezone.minutes >= 0) ? "+" : "-"
        return self.writeString("\(modifier)\(zeroedString)")
    }
}
