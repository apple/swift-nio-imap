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

class MailboxAttribute_Tests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxAttribute_Tests {
    func testEncode() {
        let inputs: [([MailboxAttribute], String, UInt)] = [
            ([], "", #line),
            ([MailboxAttribute.messageCount, .recentCount, .unseenCount], "MESSAGES RECENT UNSEEN", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            let size = self.testBuffer.writeMailboxAttributes(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_status() {
        let inputs: [(MailboxStatus, String, UInt)] = [
            (.init(), "", #line),
            (
                .init(messageCount: 1, recentCount: 2, nextUID: 3, uidValidity: 4, unseenCount: 5, size: 6, highestModificationSequence: 7),
                "MESSAGES 1 RECENT 2 UIDNEXT 3 UIDVALIDITY 4 UNSEEN 5 SIZE 6 HIGHESTMODSEQ 7",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMailboxStatus($0) })
    }
}
