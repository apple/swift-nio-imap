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

class MailboxFilter_Tests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxFilter_Tests {
    func testEncode() {
        let inputs: [(MailboxFilter, String, UInt)] = [
            (.inboxes, "inboxes", #line),
            (.personal, "personal", #line),
            (.subscribed, "subscribed", #line),
            (.subtree(Mailboxes([.init("box1")])!), "subtree (\"box1\")", #line),
            (.mailboxes(Mailboxes([.init("box1")])!), "mailboxes (\"box1\")", #line),
            (.selected, "selected", #line),
            (.selectedDelayed, "selected-delayed", #line),
            (.subtreeOne(Mailboxes([.init("box1")])!), "subtree-one (\"box1\")", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxFilter(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
