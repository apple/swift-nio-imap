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
import NIO
@testable import NIOIMAPCore

class DateTests: EncodeTestClass {

}

// MARK: - Date init
extension DateTests {
    
    func testDateInit() {
        
        let day = 25
        let month = NIOIMAP.Date.Month.jun
        let year = 1994
        let date = NIOIMAP.Date(day: day, month: month, year: year)
        
        XCTAssertEqual(date.day, day)
        XCTAssertEqual(date.month, month)
        XCTAssertEqual(date.year, year)
    }
    
}

// MARK: - Date imapEncoded
extension DateTests {
    
    func testDateImapEncoded() {
        let expected = "25-jun-1994"
        let size = self.testBuffer.writeDate(NIOIMAP.Date(day: 25, month: .jun, year: 1994))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
