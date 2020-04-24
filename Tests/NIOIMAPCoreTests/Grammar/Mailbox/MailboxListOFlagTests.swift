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

class MailboxListOFlagTests: EncodeTestClass {}

// MARK: - Encoding

extension MailboxListOFlagTests {
    func testEncode() {
        let inputs: [(NIOIMAP.Mailbox.List.OFlag, String, UInt)] = [
            (.noInferiors, "\\Noinferiors", #line),
            (.subscribed, "\\Subscribed", #line),
            (.remote, "\\Remote", #line),
            (.child(.HasChildren), "\\HasChildren", #line),
            (.other("atom"), "\\atom", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailboxListOFlag(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
