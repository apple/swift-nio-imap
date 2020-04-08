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
@testable import NIOIMAP

class EnvelopeTests: EncodeTestClass {

}

// MARK: - Encoding
extension EnvelopeTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Envelope, String, UInt)] = [
            (
                NIOIMAP.Envelope(
                    date: "01-02-03",
                    subject: nil,
                    from: [],
                    sender: [],
                    reply: [],
                    to: [],
                    cc: [],
                    bcc: [],
                    inReplyTo: nil,
                    messageID: "1"
                ),
                "(\"01-02-03\" NIL NIL NIL NIL NIL NIL NIL NIL \"1\")",
                #line
            ),
            (
                NIOIMAP.Envelope(
                    date: "01-02-03",
                    subject: "subject",
                    from: [.name("name1", adl: "adl1", mailbox: "mailbox1", host: "host1")],
                    sender: [.name("name2", adl: "adl2", mailbox: "mailbox2", host: "host2")],
                    reply: [.name("name3", adl: "adl3", mailbox: "mailbox3", host: "host3")],
                    to: [.name("name4", adl: "adl4", mailbox: "mailbox4", host: "host4")],
                    cc: [.name("name5", adl: "adl5", mailbox: "mailbox5", host: "host5")],
                    bcc: [.name("name6", adl: "adl6", mailbox: "mailbox6", host: "host6")],
                    inReplyTo: nil, messageID: "1"
                ),
                "(\"01-02-03\" \"subject\" ((\"name1\" \"adl1\" \"mailbox1\" \"host1\")) ((\"name2\" \"adl2\" \"mailbox2\" \"host2\")) ((\"name3\" \"adl3\" \"mailbox3\" \"host3\")) ((\"name4\" \"adl4\" \"mailbox4\" \"host4\")) ((\"name5\" \"adl5\" \"mailbox5\" \"host5\")) ((\"name6\" \"adl6\" \"mailbox6\" \"host6\")) NIL \"1\")",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeEnvelope(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
