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

/// The internal date and time of the message on the server.
///
/// This is not the date and time in the [RFC-2822] header, but rather a date and time
/// which reflects when the message was received.
///
/// See RFC 3501 section 2.3.3. “Internal Date Message Attribute”
///
/// IMAPv4 `date-time`
public struct InternalDate: Equatable {
    var rawValue: UInt64

    /// The components of the date, such as the day, month, year, etc.
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

        // safe to bang as we can't have an invalid `InternalDate`
        return Components(year: year, month: month, day: day, hour: hour, minute: minute, second: second, timeZoneMinutes: zoneMinutes)!
    }

    /// Creates a new `InternalDate` from a given collection of `Components`
    /// - parameter components: The components containing a year, month, day, hour, minute, second, and timezone.
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

        self.rawValue = rawValue
    }
}

extension InternalDate {
    /// Contains the individual components extracted from an `InternalDate`, and can be used to
    /// construct an `InternalDate`.
    public struct Components {
        /// The year.
        public let year: Int

        /// The month, typically represented as a 2-digit integer in the range `1...12`
        public let month: Int

        /// The day, typically represented as a 2-digit integer in the range `1...31`
        public let day: Int

        /// The hour, typically represented as a 2-digit integer in the range `0...23`
        public let hour: Int

        /// The minute, typically represented as a 2-digit integer in the range `0...59`
        public let minute: Int

        /// The second, typically represented as a 2-digit integer in the range `0...60` (to account for leap seconds)
        public let second: Int

        /// Time zone offset in minutes.
        public let zoneMinutes: Int

        /// Creates a new `Components` collection from the given parameters. Note that currently no sanity checks are performed.
        /// - parameter year: The year, typically to be represented as a 4-digit integer.
        /// - parameter month: The month, typically represented as a 2-digit integer in the range `1...12`
        /// - parameter day: The day, typically represented as a 2-digit integer in the range `1...31`
        /// - parameter hour: The hour, typically represented as a 2-digit integer in the range `0...23`
        /// - parameter minute: The minute, typically represented as a 2-digit integer in the range `0...59`
        /// - parameter second: The second, typically represented as a 2-digit integer in the range `0...60` (to account for leap seconds)
        /// - parameter zoneMinutes: The timezone as an offset in minutes from UTC.
        public init?(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, timeZoneMinutes: Int) {
            guard
                (1 ... 31).contains(day),
                (1 ... 12).contains(month),
                (0 ... 23).contains(hour),
                (0 ... 59).contains(minute),
                (0 ... 60).contains(second),
                ((-24 * 60) ... (24 * 60)).contains(timeZoneMinutes),
                (1 ... Int(UInt16.max)).contains(year)
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

extension InternalDate: Comparable {
    
    public static func < (lhs: InternalDate, rhs: InternalDate) -> Bool {
        let c1 = lhs.components, c2 = rhs.components
        if c1.year < c2.year {
            return true
        }
        if c1.month < c2.month {
            return true
        }
        if c1.day < c2.day {
            return true
        }
        if c1.hour < c2.hour {
            return true
        }
        if c1.minute < c2.minute {
            return true
        }
        if c1.second < c2.second {
            return true
        }
        if c1.zoneMinutes < c2.zoneMinutes {
            return true
        }
        return false
    }
    
}

// MARK: - Internal

extension InternalDate {
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

    fileprivate struct Time: Equatable {
        var hour: Int
        var minute: Int
        var second: Int
    }

    fileprivate struct TimeZone: Equatable {
        var minutes: Int
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInternalDate(_ date: InternalDate) -> Int {
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
            self.writeString("\"\(p.0.day)-\(monthName)-\(p.0.year) ") +
            self.writeTime(p.1) +
            self.writeSpace() +
            self.writeTimezone(p.2) +
            self.writeString("\"")
    }
}

extension EncodeBuffer {
    @discardableResult fileprivate mutating func writeTime(_ time: InternalDate.Time) -> Int {
        let hour = time.hour < 10 ? "0\(time.hour)" : "\(time.hour)"
        let minute = time.minute < 10 ? "0\(time.minute)" : "\(time.minute)"
        let second = time.second < 10 ? "0\(time.second)" : "\(time.second)"
        return self.writeString("\(hour):\(minute):\(second)")
    }
}

extension EncodeBuffer {
    @discardableResult fileprivate mutating func writeTimezone(_ timezone: InternalDate.TimeZone) -> Int {
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
