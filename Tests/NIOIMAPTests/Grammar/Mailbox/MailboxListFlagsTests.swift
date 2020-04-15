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

class MailboxListFlagsTests: EncodeTestClass {

}

// MARK: - Encoding
extension MailboxListFlagsTests {

    func testEncode() {
        let inputs: [(IMAPCore.Mailbox.List.Flags, String, UInt)] = [
            (IMAPCore.Mailbox.List.Flags(oFlags: [], sFlag: nil), "", #line),
            (IMAPCore.Mailbox.List.Flags(oFlags: [], sFlag: .marked), "\\Marked", #line),
            (IMAPCore.Mailbox.List.Flags(oFlags: [.noInferiors], sFlag: nil), "\\Noinferiors", #line),
            (IMAPCore.Mailbox.List.Flags(oFlags: [.noInferiors, .other("test")], sFlag: nil), "\\Noinferiors \\test", #line),
            (IMAPCore.Mailbox.List.Flags(oFlags: [.noInferiors, .other("test")], sFlag: .marked), "\\Marked \\Noinferiors \\test", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListFlags(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
