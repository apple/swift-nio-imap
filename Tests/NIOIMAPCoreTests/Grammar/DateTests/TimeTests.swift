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

class TimeTests: XCTestCase {}

// MARK: - Time init

extension TimeTests {
    func testTimeInit() {
        let hour = 1
        let minute = 2
        let second = 3
        let time = Date.Time(hour: hour, minute: minute, second: second)

        XCTAssertEqual(time.hour, hour)
        XCTAssertEqual(time.minute, minute)
        XCTAssertEqual(time.second, second)
    }
}
