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

    public init?(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, zoneMinutes: Int) {
        guard
            (1...31).contains(day),
            (1...12).contains(month),
            (0...24).contains(hour),
            (0...60).contains(minute),
            (0...60).contains(second),
            ((-24 * 60)...(24 * 60)).contains(zoneMinutes),
            (1...Int(UInt16.max)).contains(year),
            let zoneValue = UInt16(exactly: abs(zoneMinutes))
            else { return nil }
        let zoneIsNegative = (zoneMinutes < 0) ? 1 as UInt8 : 0

        var rawValue = 0 as UInt64

        func store<A: UnsignedInteger>(_ value: A, _ a: A) {
            rawValue *= UInt64(a + 1)
            rawValue += UInt64(value)
        }

        store(UInt16(year), 1)
        store(UInt8(zoneIsNegative), 2)
        store(UInt16(zoneValue), 24 * 60)
        store(UInt8(second), 60)
        store(UInt8(minute), 60)
        store(UInt8(hour), 60)
        store(UInt8(month), 12)
        store(UInt8(day), 31)

        self.rawValue = rawValue
    }
}

extension InternalDate {
    public struct Components {
        public let year: Int
        public let month: Int
        public let day: Int
        public let hour: Int
        public let minute: Int
        public let second: Int
        /// Time zone offset in minutes
        public let zoneMinutes: Int

        public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, zoneMinutes: Int) {
            self.year = year
            self.month = month
            self.day = day
            self.hour = hour
            self.minute = minute
            self.second = second
            self.zoneMinutes = zoneMinutes
        }
    }

    public init?(components c: Components) {
        self.init(year: c.year, month: c.month, day: c.day, hour: c.hour, minute: c.month, second: c.second, zoneMinutes: c.zoneMinutes)
    }

    public var components: Components {
        var remainder = rawValue

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

        return Components(year: year, month: month, day: day, hour: hour, minute: minute, second: second, zoneMinutes: zoneMinutes)
    }
}

// MARK: - Internal

extension InternalDate {
    fileprivate func makeParts() -> (Date, Time, TimeZone) {
        let c = components
        return (
            Date(year: c.year, month: c.month, day: c.day),
            Time(hour: c.hour, minute: c.minute, second: c.second),
            TimeZone(c.zoneMinutes)
        )
    }

    fileprivate struct Date {
        var day: Int
        var month: Int
        var year: Int

        init(year: Int, month: Int, day: Int) {
            self.day = day
            self.month = month
            self.year = year
        }
    }

    fileprivate struct Time: Equatable {
        var hour: Int
        var minute: Int
        var second: Int

        init(hour: Int, minute: Int, second: Int) {
            self.hour = hour
            self.minute = minute
            self.second = second
        }
    }

    fileprivate struct TimeZone: Equatable {
        var minutes: Int

        init(_ minutes: Int) {
            self.minutes = minutes
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInternalDate(_ date: InternalDate) -> Int {
        let p = date.makeParts()

        let monthName: String
        switch p.0.month {
        case 1: monthName = "jan"
        case 2: monthName = "feb"
        case 3: monthName = "mar"
        case 4: monthName = "apr"
        case 5: monthName = "may"
        case 6: monthName = "jun"
        case 7: monthName = "jul"
        case 8: monthName = "aug"
        case 9: monthName = "sep"
        case 10: monthName = "oct"
        case 11: monthName = "nov"
        case 12: monthName = "dec"
        default: fatalError()
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
            output.append(contentsOf: repeatElement("0", count: 4 - string.count))
            output.append(string)
            zeroedString = output
        } else {
            zeroedString = string
        }

        let modifier = (timezone.minutes >= 0) ? "+" : "-"
        return self.writeString("\(modifier)\(zeroedString)")
    }
}
