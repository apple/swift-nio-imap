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

class MailboxListTests: EncodeTestClass {

}

// MARK: - Encoding
extension MailboxListTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Mailbox.List, String, UInt)] = [
            (NIOIMAP.Mailbox.List(flags: nil, char: nil, mailbox: .inbox, listExtended: []), "() \"INBOX\"", #line),
            (NIOIMAP.Mailbox.List(flags: nil, char: "a", mailbox: .inbox, listExtended: []), "() a \"INBOX\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxList(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
