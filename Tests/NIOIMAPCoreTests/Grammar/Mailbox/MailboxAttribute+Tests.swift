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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class MailboxAttribute_Tests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxAttribute_Tests {
    func testEncode() {
        let inputs: [([MailboxAttribute], String, UInt)] = [
            ([], "", #line),
            ([MailboxAttribute.messageCount, .recentCount, .unseenCount], "MESSAGES RECENT UNSEEN", #line),
            ([MailboxAttribute.appendLimit, .uidNext, .uidValidity], "APPENDLIMIT UIDNEXT UIDVALIDITY", #line),
            ([MailboxAttribute.size], "SIZE", #line),
            ([MailboxAttribute.highestModificationSequence, .messageCount], "HIGHESTMODSEQ MESSAGES", #line),
            ([MailboxAttribute.mailboxID], "MAILBOXID", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxAttributes(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_status() {
        let inputs: [(MailboxStatus, String, UInt)] = [
            (.init(), "", #line),
            (
                .init(
                    messageCount: 133701,
                    recentCount: 255813,
                    nextUID: 377003,
                    uidValidity: 427421,
                    unseenCount: 528028,
                    size: 680543,
                    highestModificationSequence: 797237,
                    appendLimit: 86_254_193
                ),
                "MESSAGES 133701 RECENT 255813 UIDNEXT 377003 UIDVALIDITY 427421 UNSEEN 528028 SIZE 680543 HIGHESTMODSEQ 797237 APPENDLIMIT 86254193",
                #line
            ),
            (
                .init(messageCount: 133701, nextUID: 377003, uidValidity: 427421, appendLimit: 86_254_193),
                "MESSAGES 133701 UIDNEXT 377003 UIDVALIDITY 427421 APPENDLIMIT 86254193",
                #line
            ),
            (
                .init(nextUID: 377003),
                "UIDNEXT 377003",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMailboxStatus($0) })
    }
}
