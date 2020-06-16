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

class DateTests: EncodeTestClass {}

// MARK: - Date init

extension DateTests {
    func testDateInit() throws {
        let day = 25
        let month = 6
        let year = 1994
        let date = try XCTUnwrap(Date(day: day, month: month, year: year))

        XCTAssertEqual(date.day, day)
        XCTAssertEqual(date.month, month)
        XCTAssertEqual(date.year, year)
    }
}

// MARK: - Date imapEncoded

extension DateTests {
    func testDateImapEncoded() throws {
        let expected = "25-jun-1994"
        let size = self.testBuffer.writeDate(try XCTUnwrap(Date(day: 25, month: 6, year: 1994)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
