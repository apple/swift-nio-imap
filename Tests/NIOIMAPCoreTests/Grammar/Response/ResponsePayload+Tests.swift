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

class ResponsePayload_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ResponsePayload_Tests {
    func testEncode() {
        let inputs: [(ResponsePayload, String, UInt)] = [
            (.capabilityData([.enable]), "CAPABILITY IMAP4 IMAP4rev1 ENABLE", #line),
            (.conditionalState(.ok(.init(code: nil, text: "test"))), "OK test", #line),
            (.conditionalBye(.init(code: nil, text: "test")), "BYE test", #line),
            (.mailboxData(.exists(1)), "1 EXISTS", #line),
            (.messageData(.expunge(2)), "2 EXPUNGE", #line),
            (.enableData([.enable]), "ENABLED ENABLE", #line),
            (.id([.init(key: "key", value: nil)]), "ID (\"key\" NIL)", #line),
            (.quotaRoot(.init("INBOX"), .init("Root")), "QUOTAROOT \"INBOX\" \"Root\"", #line),
            (
                .quota(.init("Root"), [.init(resourceName: "STORAGE", usage: 10, limit: 512)]),
                "QUOTA \"Root\" (STORAGE 10 512)",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponsePayload(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
