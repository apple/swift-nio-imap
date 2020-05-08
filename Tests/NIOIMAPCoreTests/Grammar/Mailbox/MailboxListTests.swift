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

class MailboxListTests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxListTests {
    func testEncode() {
        let inputs: [(MailboxName.List, String, UInt)] = [
            (MailboxName.List(flags: nil, char: nil, mailbox: .inbox, listExtended: []), "() \"INBOX\"", #line),
            (MailboxName.List(flags: nil, char: "a", mailbox: .inbox, listExtended: []), "() a \"INBOX\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxList(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
