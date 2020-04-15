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



extension IMAPCore.Date {
    
    /// IMAPv4 `date-time`
    public struct DateTime: Equatable {
        public var date: IMAPCore.Date
        public var time: Time
        public var zone: TimeZone
        
        public static func date(_ date: IMAPCore.Date, time: Time, zone: TimeZone) -> Self {
            return Self(date: date, time: time, zone: zone)
        }
    }
    
}
