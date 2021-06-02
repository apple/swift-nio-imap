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

/// A date and time defined in RFC 3339.
public struct FullDateTime: Equatable {
    /// The date.
    public var date: FullDate

    /// The time.
    public var time: FullTime

    /// Creates a new `FullDateTime`.
    /// - parameter date: The date.
    /// - parameter time: The time.
    public init(date: FullDate, time: FullTime) {
        self.date = date
        self.time = time
    }
}

/// A date.
public struct FullDate: Equatable {
    /// The year. Any non-negative integer.
    public let year: Int

    /// The month in the range `1...12`.
    public let month: Int

    /// The day in the range `1...31`.
    public let day: Int

    /// Creates a new `FullDate`.
    /// - parameter year: The year. Any non-negative integer.
    /// - parameter month: The month in the range `1...12`.
    /// - parameter day: The day in the range `1...31`.
    public init(year: Int, month: Int, day: Int) {
        precondition(month > 0 && month < 13, "\(month) is not a valid month")
        precondition(day > 0 && day < 32, "\(day) is not a valid day")
        self.year = year
        self.month = month
        self.day = day
    }
}

/// A time.
public struct FullTime: Equatable {
    /// The hour. 0-based in the range `0...23`.
    public var hour: Int

    /// The minute. 0-based in the range `0...59`.
    public var minute: Int

    /// The second. 0-based in the range `0...59`.
    public var second: Int

    /// This is a partially-dynamic field, and does not directly represent
    /// milliseconds, microseconds, etc. The number you provide is the number
    /// that will be written. E.g. `123` will write `HH:mm:ss.123`, and `1234`
    /// will write `HH:mm:ss.1234`.
    public var fraction: Int?

    /// Creates a new `FullTime`. Currently no validation takes place.
    /// - parameter hour: The hour. 0-based in the range `0...23`.
    /// - parameter minute: The minute. 0-based in the range `0...59`.
    /// - parameter second: The second. 0-based in the range `0...59`.
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
        self.writeFullDate(data.date) +
            self.writeString("T") +
            self.writeFullTime(data.time)
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
        return self.writeString("\(hour):\(minute):\(second)") +
            self.writeIfExists(data.fraction) { fraction in
                self.writeString(".\(fraction)")
            }
    }

    func padInteger(_ int: Int, minimum: Int) -> String {
        let short = "\(int)"
        if short.count < minimum {
            return String(repeating: "0", count: (minimum - short.count)) + short
        } else {
            return short
        }
    }
}
