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

class MailboxDataTests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxDataTests {
    func testEncode() {
        let inputs: [(MailboxName.Data, String, UInt)] = [
            (.exists(1), "1 EXISTS", #line),
            (.flags([.answered, .deleted]), "FLAGS (\\ANSWERED \\DELETED)", #line),
            (.list(MailboxName.List(flags: nil, char: nil, mailbox: .inbox, listExtended: [])), "LIST () \"INBOX\"", #line),
            (
                .lsub(.init(flags: .init(oFlags: [.other("Draft")], sFlag: nil), char: ".", mailbox: .init("Drafts"), listExtended: [])),
                "LSUB (\\Draft) . \"Drafts\"",
                #line
            ),
            (.esearch(ESearchResponse(correlator: nil, uid: false, returnData: [.count(1)])), "ESEARCH COUNT 1", #line),
            (.esearch(ESearchResponse(correlator: nil, uid: false, returnData: [.count(1), .count(2)])), "ESEARCH COUNT 1 COUNT 2", #line),
            (.status(.inbox, [.messages(1)]), "STATUS \"INBOX\" (MESSAGES 1)", #line),
            (.status(.inbox, [.messages(1), .unseen(2)]), "STATUS \"INBOX\" (MESSAGES 1 UNSEEN 2)", #line),
            (.namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])), "NAMESPACE NIL NIL NIL", #line),
            (.search([]), "SEARCH", #line),
            (.search([1]), "SEARCH 1", #line),
            (.search([1, 2, 3, 4, 5]), "SEARCH 1 2 3 4 5", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxData(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
