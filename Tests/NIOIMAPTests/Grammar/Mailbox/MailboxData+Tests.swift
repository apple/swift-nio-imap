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

class MailboxDataTests: EncodeTestClass {

}

// MARK: - Encoding
extension MailboxDataTests {

    func testEncode() {
        let inputs: [(IMAPCore.Mailbox.Data, String, UInt)] = [
            (.exists(1), "1 EXISTS", #line),
            (.flags([.answered, .deleted]), "FLAGS (\\Answered \\Deleted)", #line),
            (.list(IMAPCore.Mailbox.List(flags: nil, char: nil, mailbox: .inbox, listExtended: [])), "LIST () \"INBOX\"", #line),
            (
                .lsub(.flags(.oFlags([.other("Draft")], sFlag: nil), char: ".", mailbox: "Drafts", listExtended: [])),
                "LSUB (\\Draft) . \"Drafts\"",
                #line
            ),
            (.search(IMAPCore.ESearchResponse(correlator: nil, uid: false, returnData: [.count(1)])), "ESEARCH COUNT 1", #line),
            (.search(IMAPCore.ESearchResponse(correlator: nil, uid: false, returnData: [.count(1), .count(2)])), "ESEARCH COUNT 1 COUNT 2", #line),
            (.status(.inbox, [.messages(1)]), "STATUS \"INBOX\" (MESSAGES 1)", #line),
            (.status(.inbox, [.messages(1), .unseen(2)]), "STATUS \"INBOX\" (MESSAGES 1 UNSEEN 2)", #line),
            (.namespace(.userNamespace([], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxData(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
