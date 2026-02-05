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

@testable import NIOIMAPCore
import Testing

@Suite("ServerMessageDate")
struct InternalDateTests {
    @Test func `component initialization and roundtrip with typical values`() {
        let components = ServerMessageDate.Components(
            year: 1994,
            month: 6,
            day: 25,
            hour: 1,
            minute: 2,
            second: 3,
            timeZoneMinutes: 620
        )!
        let date = ServerMessageDate(components)
        let c = date.components
        #expect(c.year == 1994)
        #expect(c.month == 6)
        #expect(c.day == 25)
        #expect(c.hour == 1)
        #expect(c.minute == 2)
        #expect(c.second == 3)
        #expect(c.zoneMinutes == 620)
        #expect(String(reflecting: date) == #""25-Jun-1994 01:02:03 +1020""#)
    }

    @Test func `component initialization with minimum boundary values`() {
        let components = ServerMessageDate.Components(
            year: 1900,
            month: 1,
            day: 1,
            hour: 0,
            minute: 0,
            second: 0,
            timeZoneMinutes: -959
        )!
        let date = ServerMessageDate(components)
        let c = date.components
        #expect(c.year == 1900)
        #expect(c.month == 1)
        #expect(c.day == 1)
        #expect(c.hour == 0)
        #expect(c.minute == 0)
        #expect(c.second == 0)
        #expect(c.zoneMinutes == -959)
        #expect(String(reflecting: date) == #""1-Jan-1900 00:00:00 -1559""#)
    }

    @Test func `component initialization with maximum boundary values`() {
        let components = ServerMessageDate.Components(
            year: 2579,
            month: 12,
            day: 31,
            hour: 23,
            minute: 59,
            second: 59,
            timeZoneMinutes: 959
        )!
        let date = ServerMessageDate(components)
        let c = date.components
        #expect(c.year == 2579)
        #expect(c.month == 12)
        #expect(c.day == 31)
        #expect(c.hour == 23)
        #expect(c.minute == 59)
        #expect(c.second == 59)
        #expect(c.zoneMinutes == 959)
        #expect(String(reflecting: date) == #""31-Dec-2579 23:59:59 +1559""#)
    }
}
