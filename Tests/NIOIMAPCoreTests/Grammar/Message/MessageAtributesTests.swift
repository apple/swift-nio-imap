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

class MessageAttributesTests: EncodeTestClass {}

// MARK: - Encoding

extension MessageAttributesTests {
    func testEncode() throws {
        let date = try XCTUnwrap(InternalDate(year: 1994, month: 6, day: 25, hour: 1, minute: 2, second: 3, zoneMinutes: 0))

        let inputs: [(MessageAttribute, String, UInt)] = [
            (.rfc822(nil), "RFC822 NIL", #line),
            (.rfc822Header(nil), "RFC822.HEADER NIL", #line),
            (.rfc822Header("header"), "RFC822.HEADER \"header\"", #line),
            (.rfc822Text("text"), "RFC822.TEXT \"text\"", #line),
            (.rfc822Size(123), "RFC822.SIZE 123", #line),
            (.bodySection(.init(kind: .complete), offset: nil, data: "test"), "BODY[] \"test\"", #line),
            (.bodySection(.init(kind: .header), offset: nil, data: "test"), "BODY[HEADER] \"test\"", #line),
            (.bodySection(.init(kind: .header), offset: 123, data: "test"), "BODY[HEADER]<123> \"test\"", #line),
            (.uid(123), "UID 123", #line),
            (.envelope(Envelope(date: "date", subject: "subject", from: [.init(name: "name", adl: "adl", mailbox: "mailbox", host: "host")], sender: [.init(name: "name", adl: "adl", mailbox: "mailbox", host: "host")], reply: [.init(name: "name", adl: "adl", mailbox: "mailbox", host: "host")], to: [.init(name: "name", adl: "adl", mailbox: "mailbox", host: "host")], cc: [.init(name: "name", adl: "adl", mailbox: "mailbox", host: "host")], bcc: [.init(name: "name", adl: "adl", mailbox: "mailbox", host: "host")], inReplyTo: "replyto", messageID: "abc123")), "ENVELOPE (\"date\" \"subject\" ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) ((\"name\" \"adl\" \"mailbox\" \"host\")) \"replyto\" \"abc123\")", #line),
            (.internalDate(date), #"INTERNALDATE "25-jun-1994 01:02:03 +0000""#, #line),
            (.binarySize(section: [2], size: 3), "BINARY.SIZE[2] 3", #line),
            (.binary(section: [3], data: nil), "BINARY[3] NIL", #line),
            (.binary(section: [3], data: "test"), "BINARY[3] \"test\"", #line),
            (.flags([.draft]), "FLAGS (\\DRAFT)", #line),
            (.flags([.flagged, .draft]), "FLAGS (\\FLAGGED \\DRAFT)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageAttribute(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let inputs: [([MessageAttribute], String, UInt)] = [
            ([.flags([.draft])], "(FLAGS (\\DRAFT))", #line),
            ([.flags([.flagged]), .rfc822Size(123)], "(FLAGS (\\FLAGGED) RFC822.SIZE 123)", #line),
            ([.flags([.flagged]), .rfc822Size(123), .uid(456)], "(FLAGS (\\FLAGGED) RFC822.SIZE 123 UID 456)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMessageAttributes(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
