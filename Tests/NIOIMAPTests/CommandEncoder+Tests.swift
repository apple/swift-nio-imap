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
@testable import NIOIMAP
@testable import NIOIMAPCore
import NIOTestUtils

import XCTest

final class CommandEncoder_Tests: XCTestCase {}

extension CommandEncoder_Tests {
    func testEncoding() {
        // For now this is a fairly limited sequence of test
        // just to ensure that CommandEncoder correctly uses
        // CommandEncodeBuffer.
        // When we add a state to CommandEncoder, it'll be more
        // complex and require more tests.
        let inputs: [(CommandStreamPart, ByteBuffer, UInt)] = [
            (.tagged(.init(tag: "1", command: .noop)), "1 NOOP\r\n", #line),
            (.append(.start(tag: "2", appendingTo: .inbox)), "2 APPEND \"INBOX\"", #line),
            (.idleDone, "DONE\r\n", #line),

            // SEARCH
            // We only want to include "CHARSET" if there’s a string in the search key / query.

            (
                .tagged(.init(tag: "A1", command: .search(key: .all, charset: "UTF-8"))),
                #"A1 SEARCH ALL\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .draft, charset: "UTF-8"))),
                #"A1 SEARCH DRAFT\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .uid(.set([2...80])), charset: "UTF-8"))),
                #"A1 SEARCH UID 2:80\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .sequenceNumbers(.set([2...80])), charset: "UTF-8"))),
                #"A1 SEARCH 2:80\#r\#n"#, #line
            ),

            (
                .tagged(.init(tag: "A1", command: .search(key: .and([.draft, .to("foo")]), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 DRAFT TO "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .or(.draft, .to("foo")), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 OR DRAFT TO "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .not(.to("foo")), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 NOT TO "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .bcc("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 BCC "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .body("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 BODY "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .cc("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 CC "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .from("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 FROM "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .subject("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 SUBJECT "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .text("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 TEXT "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .to("foo"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 TO "foo"\#r\#n"#, #line
            ),
            (
                .tagged(.init(tag: "A1", command: .search(key: .header("foo", "bar"), charset: "UTF-8"))),
                #"A1 SEARCH CHARSET UTF-8 HEADER "foo" "bar"\#r\#n"#, #line
            ),
        ]

        for (command, expected, line) in inputs {
            var buffer = ByteBuffer()
            let encoder = CommandEncoder(loggingMode: false)
            encoder.encode(data: command, out: &buffer)
            XCTAssertEqual(
                expected,
                buffer,
                "\(String(buffer: expected)) is not equal to \(String(buffer: buffer))",
                line: line
            )
        }
    }

    func testEncodingLoggingMode() {
        let inputs: [(CommandStreamPart, ByteBuffer, UInt)] = [
            // LOGIN / AUTHENTICATE
            (
                .tagged(.init(tag: "3", command: .login(username: "username", password: "\\pass"))),
                "3 LOGIN \"∅\" {5+}\r\n∅\r\n", #line
            ),
            (
                .tagged(
                    .init(
                        tag: "B23",
                        command: .authenticate(
                            mechanism: AuthenticationMechanism.plain,
                            initialResponse: .init(ByteBuffer(string: "foobar"))
                        )
                    )
                ), "B23 AUTHENTICATE PLAIN ∅\r\n", #line
            ),

            (.tagged(.init(tag: "1", command: .noop)), "1 NOOP\r\n", #line),
            (.idleDone, "DONE\r\n", #line),
            (
                .tagged(.init(tag: "4", command: .rename(from: .inbox, to: .init("test"), parameters: [:]))),
                "4 RENAME \"∅\" \"∅\"\r\n", #line
            ),
            (
                .tagged(
                    .init(
                        tag: "AB",
                        command: .store(
                            .set([42]),
                            [.unchangedSince(.init(modificationSequence: .init(361_656)))],
                            .flags(.add(silent: false, list: [.answered, .draft]))
                        )
                    )
                ), #"AB STORE 42 (UNCHANGEDSINCE 361656) +FLAGS (\Answered \Draft)\#r\#n"#, #line
            ),
            (
                .tagged(
                    .init(
                        tag: "AB",
                        command: .store(
                            .set([42]),
                            [.unchangedSince(.init(modificationSequence: .init(361_656)))],
                            .gmailLabels(
                                .remove(silent: false, gmailLabels: [GmailLabel(ByteBuffer(string: "foobar"))])
                            )
                        )
                    )
                ), #"AB STORE 42 (UNCHANGEDSINCE 361656) -X-GM-LABELS ("∅")\#r\#n"#, #line
            ),

            // APPEND
            (.append(.start(tag: "2", appendingTo: .inbox)), #"2 APPEND "∅""#, #line),
            (
                .append(
                    .beginMessage(
                        message: AppendMessage(
                            options: AppendOptions(
                                flagList: [.answered],
                                internalDate: ServerMessageDate(
                                    .init(
                                        year: 2022,
                                        month: 1,
                                        day: 14,
                                        hour: 13,
                                        minute: 54,
                                        second: 22,
                                        timeZoneMinutes: -120
                                    )!
                                ),
                                extensions: [:]
                            ),
                            data: AppendData(byteCount: 30_531)
                        )
                    )
                ), #" (\Answered) "14-Jan-2022 13:54:22 -0200" {30531+}\#r\#n"#, #line
            ),
            (.append(.messageBytes(ByteBuffer(string: "foobar"))), "", #line),
            (.append(.endMessage), "∅", #line),
            (.append(.finish), "\r\n", #line),
        ]

        for (command, expected, line) in inputs {
            var buffer = ByteBuffer()
            let encoder = CommandEncoder(loggingMode: true)
            encoder.capabilities.append(.literalPlus)
            encoder.encode(data: command, out: &buffer)
            XCTAssertEqual(
                expected,
                buffer,
                "'\(String(buffer: expected))' is not equal to '\(String(buffer: buffer))'",
                line: line
            )
        }
    }
}
