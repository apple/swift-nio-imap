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

class GrammarParser_Envelope_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseEnvelope

extension GrammarParser_Envelope_Tests {
    func testParseEnvelopeTo_valid() {
        TestUtilities.withBuffer(#"("date" "subject" (("name1" "adl1" "mailbox1" "host1")) (("name2" "adl2" "mailbox2" "host2")) (("name3" "adl3" "mailbox3" "host3")) (("name4" "adl4" "mailbox4" "host4")) (("name5" "adl5" "mailbox5" "host5")) (("name6" "adl6" "mailbox6" "host6")) "someone" "messageid")"#) { (buffer) in
            let envelope = try GrammarParser.parseEnvelope(buffer: &buffer, tracker: .testTracker)
            XCTAssertEqual(envelope.date, "date")
            XCTAssertEqual(envelope.subject, "subject")
            XCTAssertEqual(envelope.from, [.init(name: "name1", adl: "adl1", mailbox: "mailbox1", host: "host1")])
            XCTAssertEqual(envelope.sender, [.init(name: "name2", adl: "adl2", mailbox: "mailbox2", host: "host2")])
            XCTAssertEqual(envelope.reply, [.init(name: "name3", adl: "adl3", mailbox: "mailbox3", host: "host3")])
            XCTAssertEqual(envelope.to, [.init(name: "name4", adl: "adl4", mailbox: "mailbox4", host: "host4")])
            XCTAssertEqual(envelope.cc, [.init(name: "name5", adl: "adl5", mailbox: "mailbox5", host: "host5")])
            XCTAssertEqual(envelope.bcc, [.init(name: "name6", adl: "adl6", mailbox: "mailbox6", host: "host6")])
            XCTAssertEqual(envelope.inReplyTo, "someone")
            XCTAssertEqual(envelope.messageID, "messageid")
        }
    }
}
