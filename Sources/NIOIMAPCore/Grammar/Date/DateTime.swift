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

extension NIOIMAP.Date {
    
    /// IMAPv4 `date-time`
    public struct DateTime: Equatable {
        public var date: NIOIMAP.Date
        public var time: Time
        public var zone: TimeZone
        
        public static func date(_ date: NIOIMAP.Date, time: Time, zone: TimeZone) -> Self {
            return Self(date: date, time: time, zone: zone)
        }
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeDateTime(_ dateTime: NIOIMAP.Date.DateTime) -> Int {
        self.writeString("\"\(dateTime.date.day)-\(dateTime.date.month.rawValue)-\(dateTime.date.year) ") +
        self.writeTime(dateTime.time) +
        self.writeSpace() +
        self.writeTimezone(dateTime.zone) +
        self.writeString("\"")
    }
    
}
