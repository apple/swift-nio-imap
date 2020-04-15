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
@testable import IMAPCore
@testable import NIOIMAP

class MailboxListSFlagTests: EncodeTestClass {

}

// MARK: - init
extension MailboxListSFlagTests {


    func testInit() {

        let inputs: [(String, IMAPCore.Mailbox.List.SFlag?, UInt)] = [
            (#"\fecd"#, nil, #line),
            (#"\Noselect"#, .noSelect, #line),
            (#"\NOSELECT"#, .noSelect, #line),
            (#"\noselect"#, .noSelect, #line),
            (#"\Marked"#, .marked, #line),
            (#"\MARKED"#, .marked, #line),
            (#"\marked"#, .marked, #line),
            (#"\Unmarked"#, .unmarked, #line),
            (#"\UNMARKED"#, .unmarked, #line),
            (#"\unmarked"#, .unmarked, #line),
            (#"\Nonexistent"#, .nonExistent, #line),
            (#"\NONEXISTENT"#, .nonExistent, #line),
            (#"\nonexistent"#, .nonExistent, #line),
        ]

        for (test, expected, line) in inputs {
            let testValue = IMAPCore.Mailbox.List.SFlag(rawValue: test)
            XCTAssertEqual(testValue, expected, line: line)
        }

    }

}

// MARK: - Encoding
extension MailboxListSFlagTests {

    func testEncode() {
        let inputs: [(IMAPCore.Mailbox.List.SFlag, String, UInt)] = [
            (.marked, #"\Marked"#, #line),
            (.noSelect, #"\Noselect"#, #line),
            (.unmarked, #"\Unmarked"#, #line),
            (.nonExistent, #"\Nonexistent"#, #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListSFlag(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

}
