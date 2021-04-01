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
    func testEncode() throws {
        let components = ServerMessageDate.Components(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, timeZoneMinutes: 0)!
        let date = ServerMessageDate(components)

        let inputs: [(AppendOptions, String, UInt)] = [
            (.none, "", #line),
            (.init(flagList: [.answered], internalDate: nil, extensions: [:]), " (\\Answered)", #line),
            (.init(flagList: [.answered], internalDate: date, extensions: [:]), " (\\Answered) \"25-Jun-1994 01:02:03 +0000\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            let size = self.testBuffer.writeAppendOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
