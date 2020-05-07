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

extension Date {
    /// IMAPv4 `date-time`
    public struct DateTime: Equatable {
        public var date: Date
        public var time: Time
        public var zone: TimeZone

        public init(date: NIOIMAP.Date, time: NIOIMAP.Date.Time, zone: NIOIMAP.Date.TimeZone) {
            self.date = date
            self.time = time
            self.zone = zone
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeDateTime(_ dateTime: Date.DateTime) -> Int {
        self.writeString("\"\(dateTime.date.day)-\(dateTime.date.month.rawValue)-\(dateTime.date.year) ") +
            self.writeTime(dateTime.time) +
            self.writeSpace() +
            self.writeTimezone(dateTime.zone) +
            self.writeString("\"")
    }
}
