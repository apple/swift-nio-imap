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

import XCTest
@testable import IMAPCore
@testable import NIOIMAP

class DateTimeTests: XCTestCase {

}

// MARK: - DateTime init
extension DateTimeTests {
    
    func testDateTimeInit() {
        
        let date = IMAPCore.Date(day: 25, month: .jun, year: 1994)
        let time = IMAPCore.Date.Time(hour: 01, minute: 02, second: 03)
        let zone = IMAPCore.Date.TimeZone(999)!
        let dateTime = IMAPCore.Date.DateTime(date: date, time: time, zone: zone)
        
        XCTAssertEqual(dateTime.date, date)
        XCTAssertEqual(dateTime.time, time)
        XCTAssertEqual(dateTime.zone, zone)
    }
    
}
