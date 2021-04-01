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

class InternalDateTests: XCTestCase {}

// MARK: - ServerMessageDate init

extension InternalDateTests {
    func testInternalDateInit_1() {
        let components = ServerMessageDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 620)!
        let date = ServerMessageDate(components)
        let c = date.components
        XCTAssertEqual(c.year, 1994)
        XCTAssertEqual(c.month, 6)
        XCTAssertEqual(c.day, 25)
        XCTAssertEqual(c.hour, 1)
        XCTAssertEqual(c.minute, 2)
        XCTAssertEqual(c.second, 3)
        XCTAssertEqual(c.zoneMinutes, 620)
    }

    func testInternalDateInit_2() {
        let components = ServerMessageDate.Components(year: 1900, month: 1, day: 1, hour: 0, minute: 0, second: 0, timeZoneMinutes: -959)!
        let date = ServerMessageDate(components)
        let c = date.components
        XCTAssertEqual(c.year, 1900)
        XCTAssertEqual(c.month, 1)
        XCTAssertEqual(c.day, 1)
        XCTAssertEqual(c.hour, 0)
        XCTAssertEqual(c.minute, 0)
        XCTAssertEqual(c.second, 0)
        XCTAssertEqual(c.zoneMinutes, -959)
    }

    func testInternalDateInit_3() {
        let components = ServerMessageDate.Components(year: 2579, month: 12, day: 31, hour: 23, minute: 59, second: 59, timeZoneMinutes: 959)!
        let date = ServerMessageDate(components)
        let c = date.components
        XCTAssertEqual(c.year, 2579)
        XCTAssertEqual(c.month, 12)
        XCTAssertEqual(c.day, 31)
        XCTAssertEqual(c.hour, 23)
        XCTAssertEqual(c.minute, 59)
        XCTAssertEqual(c.second, 59)
        XCTAssertEqual(c.zoneMinutes, 959)
    }
}
