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

import NIO
@testable import NIOIMAPCore
import XCTest

class TimezoneTests: EncodeTestClass {}

// MARK: - init

extension TimezoneTests {
    // stupid test, but I want the test coverage
    func testTimezoneInit() {
        let zone = Date.TimeZone(1000)
        XCTAssertNotNil(zone)
        XCTAssertEqual(zone, Date.TimeZone(1000))
    }
}

// MARK: - Encoding

extension TimezoneTests {
    func testPositive() {
        let expected = "+1000"
        let size = self.testBuffer.writeTimezone(Date.TimeZone(1000)!)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testNegative() {
        let expected = "-1000"
        let size = self.testBuffer.writeTimezone(Date.TimeZone(-1000)!)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testTooShort() {
        let expected = "+0100"
        let size = self.testBuffer.writeTimezone(Date.TimeZone(100)!)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
