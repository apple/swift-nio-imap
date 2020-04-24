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

class MessageAttributesStaticTests: EncodeTestClass {}

// MARK: - Encoding

extension MessageAttributesStaticTests {
    func testEncode() {
        let inputs: [(NIOIMAP.MessageAttributesStatic, String, UInt)] = [
            (.rfc822(.header, "something"), "RFC822.HEADER \"something\"", #line),
            (.rfc822(nil, nil), "RFC822 NIL", #line),
            (.rfc822Size(123), "RFC822.SIZE 123", #line),
            (.bodySectionText(nil, 123), "BODY[TEXT] {123}\r\n", #line),
            (.bodySectionText(123, 456), "BODY[TEXT]<123> {456}\r\n", #line),
            (.bodySection(.text(.header), nil, "test"), "BODY[HEADER] \"test\"", #line),
            (.bodySection(.text(.header), 123, "test"), "BODY[HEADER]<123> \"test\"", #line),
            (.uid(123), "UID 123", #line),
            (.envelope(NIOIMAP.Envelope(date: "date", subject: "subject", from: [.name("name", adl: "adl", mailbox: "mailbox", host: "host")], sender: [.name("name", adl: "adl", mailbox: "mailbox", host: "host")], reply: [.name("name", adl: "adl", mailbox: "mailbox", host: "host")], to: [.name("name", adl: "adl", mailbox: "mailbox", host: "host")], cc: [.name("name", adl: "adl", mailbox: "mailbox", host: "host")], bcc: [.name("name", adl: "adl", mailbox: "mailbox", host: "host")], inReplyTo: "replyto", messageID: "abc123")), "ENVELOPE (\"date\" \"subject\" ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) \"replyto\" \"abc123\")", #line),
            (.internalDate(.date(.day(25, month: .jun, year: 1994), time: NIOIMAP.Date.Time(hour: 01, minute: 02, second: 03), zone: NIOIMAP.Date.TimeZone(0)!)), #"INTERNALDATE "25-jun-1994 01:02:03 +0000""#, #line),
            (.binarySize(section: [2], number: 3), "BINARY.SIZE[2] 3", #line),
            (.binaryString(section: [3], string: nil), "BINARY[3] NIL", #line),
            (.binaryString(section: [3], string: "test"), "BINARY[3] \"test\"", #line),
            (.binaryLiteral(section: [4], size: 3), "BINARY[4] {3}\r\n", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageAttributeStatic(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
