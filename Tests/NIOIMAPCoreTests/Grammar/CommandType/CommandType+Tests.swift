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

class CommandType_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CommandType_Tests {
    func testEncode() {
        let inputs: [(Command, CommandEncodingOptions, [String], UInt)] = [
            (.list(nil, reference: .init(""), .mailbox(""), []), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            (.list(nil, reference: .init(""), .mailbox("")), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            // no ret-opts but has capability
            (.list(nil, reference: .init(""), .mailbox("")), CommandEncodingOptions(), ["LIST \"\" \"\""], #line),
            (
                .list(nil, reference: .inbox, .mailbox(""), [.children]), CommandEncodingOptions(),
                ["LIST \"INBOX\" \"\" RETURN (CHILDREN)"], #line
            ),  // ret-opts with capability

            (.namespace, CommandEncodingOptions(), ["NAMESPACE"], #line),

            // MARK: Login

            (
                .login(username: "username", password: "password"), CommandEncodingOptions(),
                [#"LOGIN "username" "password""#], #line
            ),
            (
                .login(username: "david evans", password: "great password"), CommandEncodingOptions(),
                [#"LOGIN "david evans" "great password""#], #line
            ),
            (
                .login(username: "\r\n", password: "\\\""), CommandEncodingOptions(),
                ["LOGIN {2}\r\n", "\r\n {2}\r\n", "\\\""], #line
            ),

            (.select(MailboxName("Events")), CommandEncodingOptions(), [#"SELECT "Events""#], #line),
            (
                .select(.inbox, [.basic(.init(key: "test", value: nil))]), CommandEncodingOptions(),
                [#"SELECT "INBOX" (test)"#], #line
            ),
            (
                .select(.inbox, [.basic(.init(key: "test1", value: nil)), .basic(.init(key: "test2", value: nil))]),
                CommandEncodingOptions(), [#"SELECT "INBOX" (test1 test2)"#], #line
            ),
            (.examine(MailboxName("Events")), CommandEncodingOptions(), [#"EXAMINE "Events""#], #line),
            (
                .examine(.inbox, [.basic(.init(key: "test", value: nil))]), CommandEncodingOptions(),
                [#"EXAMINE "INBOX" (test)"#], #line
            ),
            (.move(.set([1]), .inbox), CommandEncodingOptions(), ["MOVE 1 \"INBOX\""], #line),
            (.id([:]), CommandEncodingOptions(), ["ID NIL"], #line),
            (
                .getMetadata(options: [], mailbox: .inbox, entries: ["a"]), CommandEncodingOptions(),
                ["GETMETADATA \"INBOX\" (\"a\")"], #line
            ),
            (
                .getMetadata(options: [.maxSize(123)], mailbox: .inbox, entries: ["a"]), CommandEncodingOptions(),
                ["GETMETADATA (MAXSIZE 123) \"INBOX\" (\"a\")"], #line
            ),
            (
                .setMetadata(mailbox: .inbox, entries: ["a": nil]), CommandEncodingOptions(),
                ["SETMETADATA \"INBOX\" (\"a\" NIL)"], #line
            ),

            (
                .fetch(.set([1...40]), [.uid, .internalDate], []), CommandEncodingOptions(),
                ["FETCH 1:40 (UID INTERNALDATE)"], #line
            ),
            (
                .fetch(
                    .set([77]),
                    [.uid, .bodySection(peek: true, .header, nil)],
                    [.changedSince(.init(modificationSequence: 707_484_939_116_871_680))]
                ), CommandEncodingOptions(), ["FETCH 77 (UID BODY.PEEK[HEADER]) (CHANGEDSINCE 707484939116871680)"],
                #line
            ),

            (.resetKey(mailbox: nil, mechanisms: []), CommandEncodingOptions(), ["RESETKEY"], #line),
            // no mailbox, so no mechanisms written
            (.resetKey(mailbox: nil, mechanisms: [.internal]), CommandEncodingOptions(), ["RESETKEY"], #line),
            (
                .resetKey(mailbox: .inbox, mechanisms: [.internal]), CommandEncodingOptions(),
                ["RESETKEY \"INBOX\" INTERNAL"], #line
            ),
            (
                .resetKey(mailbox: .inbox, mechanisms: [.internal, .init("test")]), CommandEncodingOptions(),
                ["RESETKEY \"INBOX\" INTERNAL test"], #line
            ),

            (
                .generateAuthorizedURL([.init(urlRump: "rump1", mechanism: .internal)]), CommandEncodingOptions(),
                ["GENURLAUTH \"rump1\" INTERNAL"], #line
            ),
            (
                .generateAuthorizedURL([
                    .init(urlRump: "rump2", mechanism: .internal), .init(urlRump: "rump3", mechanism: .init("test")),
                ]), CommandEncodingOptions(), ["GENURLAUTH \"rump2\" INTERNAL \"rump3\" test"], #line
            ),

            (.urlFetch(["test"]), CommandEncodingOptions(), ["URLFETCH test"], #line),
            (.urlFetch(["test1", "test2"]), CommandEncodingOptions(), ["URLFETCH test1 test2"], #line),

            (.create(.inbox, []), CommandEncodingOptions(), ["CREATE \"INBOX\""], #line),
            (
                .create(.inbox, [.attributes([.archive, .drafts, .flagged])]), CommandEncodingOptions(),
                ["CREATE \"INBOX\" (USE (\\Archive \\Drafts \\Flagged))"], #line
            ),
            (.compress(.deflate), CommandEncodingOptions(), ["COMPRESS DEFLATE"], #line),
            (.uidBatches(batchSize: 2_000), CommandEncodingOptions(), ["UIDBATCHES 2000"], #line),
            (
                .uidBatches(batchSize: 1_000, batchRange: 10...20), CommandEncodingOptions(), ["UIDBATCHES 1000 10:20"],
                #line
            ),

            // Custom

            (.custom(name: "FOOBAR", payloads: []), CommandEncodingOptions(), ["FOOBAR"], #line),
            (
                .custom(name: "FOOBAR", payloads: [.verbatim(.init(string: "A B C"))]), CommandEncodingOptions(),
                ["FOOBAR A B C"], #line
            ),
            (
                .custom(name: "FOOBAR", payloads: [.verbatim(.init(string: "A")), .verbatim(.init(string: "B"))]),
                CommandEncodingOptions(), ["FOOBAR AB"], #line
            ),
            (
                .custom(name: "FOOBAR", payloads: [.literal(.init(string: "A"))]), CommandEncodingOptions(),
                [#"FOOBAR "A""#], #line
            ),
            (
                .custom(name: "FOOBAR", payloads: [.literal(.init(string: "A B C"))]), CommandEncodingOptions(),
                [#"FOOBAR "A B C""#], #line
            ),
            (
                .custom(name: "FOOBAR", payloads: [.literal(.init(string: "A")), .literal(.init(string: "B"))]),
                CommandEncodingOptions(), [#"FOOBAR "A""B""#], #line
            ),
            (
                .custom(
                    name: "FOOBAR",
                    payloads: [
                        .literal(.init(string: "A")), .verbatim(.init(string: " ")), .literal(.init(string: "B")),
                    ]
                ), CommandEncodingOptions(), [#"FOOBAR "A" "B""#], #line
            ),
            (
                .custom(name: "FOOBAR", payloads: [.literal(.init(string: "¶"))]), CommandEncodingOptions(),
                ["FOOBAR {2}\r\n", "¶"], #line
            ),
        ]

        for (test, options, expectedStrings, line) in inputs {
            var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: options, loggingMode: false)
            let size = encodeBuffer.writeCommand(test)
            self.testBuffer = encodeBuffer.buffer
            XCTAssertEqual(size, expectedStrings.reduce(0) { $0 + $1.utf8.count }, line: line)
            XCTAssertEqual(self.testBufferStrings, expectedStrings, line: line)
        }
    }
}
