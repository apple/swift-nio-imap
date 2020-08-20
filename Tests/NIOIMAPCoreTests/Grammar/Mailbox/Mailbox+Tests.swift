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

class Mailbox_Tests: EncodeTestClass {
    func testDisplayString() {
        let inputs: [(MailboxName, String, UInt)] = [
            (.init(ByteBuffer(string: "")), "", #line),
            (.init(ByteBuffer(string: "a")), "a", #line),
            (.init(ByteBuffer(string: "a/b")), "a/b", #line),
            (.init(ByteBuffer(string: "a/&2D7d0dg83,0gDdg+3bM-/c")), "a/🧑🏽‍🦳/c", #line),
        ]

        for (test, expectedString, line) in inputs {
            XCTAssertNoThrow(XCTAssertEqual(try test.displayString(), expectedString, line: line), line: line)
        }
    }

    func testEncode() {
        let inputs: [(MailboxName, String, UInt)] = [
            (.inbox, "\"INBOX\"", #line),
            (.init(""), "\"\"", #line),
            (.init("box"), "\"box\"", #line),
            (.init("\""), "{1}\r\n\"", #line),
            (.init(String(bytes: [0x42, 0xC3, 0xA5, 0x64], encoding: .utf8)!), "{4}\r\nBåd", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMailbox(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
