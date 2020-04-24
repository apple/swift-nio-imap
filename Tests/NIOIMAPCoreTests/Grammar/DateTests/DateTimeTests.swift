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
import XCTest

class DateTimeTests: XCTestCase {}

// MARK: - DateTime init

extension DateTimeTests {
    func testDateTimeInit() {
        let date = NIOIMAP.Date(day: 25, month: .jun, year: 1994)
        let time = NIOIMAP.Date.Time(hour: 01, minute: 02, second: 03)
        let zone = NIOIMAP.Date.TimeZone(999)!
        let dateTime = NIOIMAP.Date.DateTime(date: date, time: time, zone: zone)

        XCTAssertEqual(dateTime.date, date)
        XCTAssertEqual(dateTime.time, time)
        XCTAssertEqual(dateTime.zone, zone)
    }
}
