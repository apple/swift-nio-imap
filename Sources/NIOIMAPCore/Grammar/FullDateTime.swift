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

/// RFC 3339 date-time
public struct FullDateTime: Equatable {
    public var date: FullDate
    public var time: FullTime

    public init(date: FullDate, time: FullTime) {
        self.date = date
        self.time = time
    }
}

public struct FullDate: Equatable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        precondition(month > 0 && month < 13, "\(month) is not a valid month")
        precondition(day > 0 && day < 32, "\(day) is not a valid day")
        self.year = year
        self.month = month
        self.day = day
    }
}

public struct FullTime: Equatable {
    public var hour: Int
    public var minute: Int
    public var second: Int

    /// This is a partially-dynamic field, and does not directly represent
    /// milliseconds, microseconds, etc. The number you provide is the number
    /// that will be written. E.g. `123` will write `HH:mm:ss.123`, and `1234`
    /// will write `HH:mm:ss.1234`.
    public var fraction: Int?

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
