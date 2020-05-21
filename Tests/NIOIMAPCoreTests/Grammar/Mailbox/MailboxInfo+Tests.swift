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

class MailboxInfo_Tests: EncodeTestClass {}

// MARK: - init

extension MailboxListSFlagTests {
    func testInit() {
        let inputs: [(String, MailboxInfo.SFlag?, UInt)] = [
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
            let testValue = MailboxInfo.SFlag(rawValue: test)
            XCTAssertEqual(testValue, expected, line: line)
        }
    }
}

// MARK: - Encoding

extension MailboxInfo_Tests {
    func testEncode() {
        let inputs: [(MailboxInfo, String, UInt)] = [
            (MailboxInfo(flags: nil, char: nil, mailbox: .inbox, listExtended: []), "() \"INBOX\"", #line),
            (MailboxInfo(flags: nil, char: "a", mailbox: .inbox, listExtended: []), "() a \"INBOX\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxInfo(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
    func testEncode_flags() {
        let inputs: [(MailboxInfo.Flags, String, UInt)] = [
            (MailboxInfo.Flags(oFlags: [], sFlag: nil), "", #line),
            (MailboxInfo.Flags(oFlags: [], sFlag: .marked), "\\Marked", #line),
            (MailboxInfo.Flags(oFlags: [.noInferiors], sFlag: nil), "\\Noinferiors", #line),
            (MailboxInfo.Flags(oFlags: [.noInferiors, .other("test")], sFlag: nil), "\\Noinferiors \\test", #line),
            (MailboxInfo.Flags(oFlags: [.noInferiors, .other("test")], sFlag: .marked), "\\Marked \\Noinferiors \\test", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListFlags(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
    func testEncode_oFlags() {
        let inputs: [(MailboxInfo.Flags, String, UInt)] = [
            (MailboxInfo.Flags(oFlags: [], sFlag: nil), "", #line),
            (MailboxInfo.Flags(oFlags: [], sFlag: .marked), "\\Marked", #line),
            (MailboxInfo.Flags(oFlags: [.noInferiors], sFlag: nil), "\\Noinferiors", #line),
            (MailboxInfo.Flags(oFlags: [.noInferiors, .other("test")], sFlag: nil), "\\Noinferiors \\test", #line),
            (MailboxInfo.Flags(oFlags: [.noInferiors, .other("test")], sFlag: .marked), "\\Marked \\Noinferiors \\test", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListFlags(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
    func testEncode_sFlag() {
        let inputs: [(MailboxInfo.SFlag, String, UInt)] = [
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
