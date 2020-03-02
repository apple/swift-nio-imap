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
@testable import NIOIMAP

class AppendOptions_Tests: EncodeTestClass {

}

extension AppendOptions_Tests {
    
    func testEncode() {
        
        let inputs: [(NIOIMAP.AppendOptions, String, UInt)] = [
            (.flagList(nil, dateTime: nil, extensions: []), "", #line),
            (.flagList([.answered], dateTime: nil, extensions: []), " (\\Answered)", #line),
            (.flagList([.answered], dateTime: .init(date: .init(day: 25, month: .jun, year: 1994), time: .init(hour: 01, minute: 02, second: 03), zone: NIOIMAP.Date.TimeZone(0)!), extensions: []), " (\\Answered) \"25-jun-1994 01:02:03 +0000\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeAppendOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
        
    }
    
}
