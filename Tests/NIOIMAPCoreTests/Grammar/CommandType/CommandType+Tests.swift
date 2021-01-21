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

class CommandType_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CommandType_Tests {
    func testEncode() {
        let inputs: [(Command, CommandEncodingOptions, [String], UInt)] = [
            (.list(nil, reference: .init(""), .mailbox(""), []), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            (.list(nil, reference: .init(""), .mailbox("")), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            (.list(nil, reference: .init(""), .mailbox("")), CommandEncodingOptions(), ["LIST \"\" \"\""], #line), // no ret-opts but has capability
            (.list(nil, reference: .inbox, .mailbox(""), [.children]), CommandEncodingOptions(), ["LIST \"INBOX\" \"\" RETURN (CHILDREN)"], #line), // ret-opts with capability

            (.namespace, CommandEncodingOptions(), ["NAMESPACE"], #line),

            // MARK: Login

            (.login(username: "username", password: "password"), CommandEncodingOptions(), [#"LOGIN "username" "password""#], #line),
            (.login(username: "david evans", password: "great password"), CommandEncodingOptions(), [#"LOGIN "david evans" "great password""#], #line),
            (.login(username: "\r\n", password: "\\\""), CommandEncodingOptions(), ["LOGIN {2}\r\n", "\r\n {2}\r\n", "\\\""], #line),

            (.select(MailboxName("Events")), CommandEncodingOptions(), [#"SELECT "Events""#], #line),
            (.select(.inbox, [.basic(.init(name: "test"))]), CommandEncodingOptions(), [#"SELECT "INBOX" (test)"#], #line),
            (.select(.inbox, [.basic(.init(name: "test1")), .basic(.init(name: "test2"))]), CommandEncodingOptions(), [#"SELECT "INBOX" (test1 test2)"#], #line),
            (.examine(MailboxName("Events")), CommandEncodingOptions(), [#"EXAMINE "Events""#], #line),
            (.examine(.inbox, [.init(name: "test")]), CommandEncodingOptions(), [#"EXAMINE "INBOX" (test)"#], #line),
            (.move([1], .inbox), CommandEncodingOptions(), ["MOVE 1 \"INBOX\""], #line),
            (.id([]), CommandEncodingOptions(), ["ID NIL"], #line),
            (.getMetadata(options: [], mailbox: .inbox, entries: ["a"]), CommandEncodingOptions(), ["GETMETADATA \"INBOX\" (\"a\")"], #line),
            (.getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a"]), CommandEncodingOptions(), ["GETMETADATA (MAXSIZE 123) \"INBOX\" (\"a\")"], #line),
            (.setMetadata(mailbox: .inbox, entries: [.init(name: "a", value: nil)]), CommandEncodingOptions(), ["SETMETADATA \"INBOX\" (\"a\" NIL)"], #line),

            (.resetKey(mailbox: nil, mechanisms: []), CommandEncodingOptions(), ["RESETKEY"], #line),
            (.resetKey(mailbox: nil, mechanisms: [.internal]), CommandEncodingOptions(), ["RESETKEY"], #line), // no mailbox, so no mechanisms written
            (.resetKey(mailbox: .inbox, mechanisms: [.internal]), CommandEncodingOptions(), ["RESETKEY \"INBOX\" INTERNAL"], #line),
            (.resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]), CommandEncodingOptions(), ["RESETKEY \"INBOX\" INTERNAL test"], #line),

            (.genURLAuth([.init(urlRump: "rump1", mechanism: .internal)]), CommandEncodingOptions(), ["GENURLAUTH \"rump1\" INTERNAL"], #line),
            (.genURLAuth([.init(urlRump: "rump2", mechanism: .internal), .init(urlRump: "rump3", mechanism: .init("test"))]), CommandEncodingOptions(), ["GENURLAUTH \"rump2\" INTERNAL \"rump3\" test"], #line),

            (.urlFetch(["test"]), CommandEncodingOptions(), ["URLFETCH test"], #line),
            (.urlFetch(["test1", "test2"]), CommandEncodingOptions(), ["URLFETCH test1 test2"], #line),
            
            (.create(.inbox, []), CommandEncodingOptions(), ["CREATE \"INBOX\""], #line),
            (.create(.inbox, [.attributes([.archive, .drafts, .flagged])]), CommandEncodingOptions(), ["CREATE \"INBOX\" USE (\\archive \\drafts \\flagged)"], #line)
        ]

        for (test, options, expectedStrings, line) in inputs {
            var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: options)
            let size = encodeBuffer.writeCommand(test)
            self.testBuffer = encodeBuffer.buffer
            XCTAssertEqual(size, expectedStrings.reduce(0) { $0 + $1.utf8.count }, line: line)
            XCTAssertEqual(self.testBufferStrings, expectedStrings, line: line)
        }
    }
}
