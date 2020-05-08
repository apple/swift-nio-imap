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

class AppendOptions_Tests: EncodeTestClass {}

extension AppendOptions_Tests {
    func testEncode() {
        let inputs: [(AppendOptions, String, UInt)] = [
            (.flagList([], dateTime: nil, extensions: []), "", #line),
            (.flagList([.answered], dateTime: nil, extensions: []), " (\\ANSWERED)", #line),
            (.flagList([.answered], dateTime: .date(.day(25, month: .jun, year: 1994), time: .hour(01, minute: 02, second: 03), zone: Date.TimeZone(0)!), extensions: []), " (\\ANSWERED) \"25-jun-1994 01:02:03 +0000\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeAppendOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
