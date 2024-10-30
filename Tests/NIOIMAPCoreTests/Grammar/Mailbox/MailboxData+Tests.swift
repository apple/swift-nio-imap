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

class MailboxDataTests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxDataTests {
    func testEncode() {
        let inputs: [(MailboxData, String, UInt)] = [
            (.exists(1), "1 EXISTS", #line),
            (.flags([.answered, .deleted]), "FLAGS (\\Answered \\Deleted)", #line),
            (
                .list(MailboxInfo(attributes: [], path: try! .init(name: .inbox), extensions: [:])),
                "LIST () NIL \"INBOX\"", #line
            ),
            (
                .lsub(
                    .init(
                        attributes: [.init("\\draft")],
                        path: try! .init(name: .init("Drafts"), pathSeparator: "."),
                        extensions: [:]
                    )
                ),
                "LSUB (\\draft) \".\" \"Drafts\"",
                #line
            ),
            (
                .extendedSearch(
                    ExtendedSearchResponse(correlator: nil, kind: .sequenceNumber, returnData: [.count(1)])
                ), "ESEARCH COUNT 1", #line
            ),
            (
                .extendedSearch(
                    ExtendedSearchResponse(correlator: nil, kind: .sequenceNumber, returnData: [.count(1), .count(2)])
                ), "ESEARCH COUNT 1 COUNT 2", #line
            ),
            (.status(.inbox, .init(messageCount: 1)), "STATUS \"INBOX\" (MESSAGES 1)", #line),
            (.status(.inbox, .init(messageCount: 1, unseenCount: 2)), "STATUS \"INBOX\" (MESSAGES 1 UNSEEN 2)", #line),
            (
                .namespace(.init(userNamespace: [], otherUserNamespace: [], sharedNamespace: [])),
                "NAMESPACE NIL NIL NIL", #line
            ),
            (.search([]), "SEARCH", #line),
            (.search([1]), "SEARCH 1", #line),
            (.search([1, 2, 3, 4, 5]), "SEARCH 1 2 3 4 5", #line),
            (.search([20, 23], ModificationSequenceValue(917_162_500)), "SEARCH 20 23 (MODSEQ 917162500)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxData(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_searchSort() {
        let inputs: [(MailboxData.SearchSort?, String, UInt)] = [
            (nil, "SEARCH", #line),
            (.init(identifiers: [1], modificationSequence: 2), "SEARCH 1 (MODSEQ 2)", #line),
            (.init(identifiers: [1, 2, 3], modificationSequence: 2), "SEARCH 1 2 3 (MODSEQ 2)", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMailboxDataSearchSort($0) })
    }
}
