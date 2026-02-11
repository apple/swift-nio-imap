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
import NIOTestUtils
import XCTest

// MARK: - General usage tests

extension ParserUnitTests {
    func testCommandToStreamToCommand() {
        // 1 NOOP
        // 2 APPEND INBOX {10}\r\n01234567890
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 APPEND INBOX {10}\r\n0123456789\r\n3 NOOP\r\n"

        var parser = CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(
                c1,
                SynchronizedCommand(.tagged(TaggedCommand(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 1)
            )
            XCTAssertEqual(c2_1, SynchronizedCommand(.append(.start(tag: "2", appendingTo: .inbox))))
            XCTAssertEqual(
                c2_2,
                SynchronizedCommand(.append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 10)))))
            )
            XCTAssertEqual(c2_3, SynchronizedCommand(.append(.messageBytes("0123456789"))))
            XCTAssertEqual(c2_4, SynchronizedCommand(.append(.endMessage)))
            XCTAssertEqual(c2_5, SynchronizedCommand(.append(.finish)))
            XCTAssertEqual(c3, SynchronizedCommand(.tagged(TaggedCommand(tag: "3", command: .noop))))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCommandToStreamToCommand_catenateExampleOne() {
        var buffer = ByteBuffer(
            string: #"1 NOOP\#r\#n"#
                + #"A003 APPEND Drafts (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {42}\#r\#n"#
                + #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME" "#
                + #"URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1" TEXT {42}\#r\#n"#
                + #"\#r\#n--------------030308070208000400050907\#r\#n"#
                + #" URL "/Drafts;UIDVALIDITY=385759045/;UID=30" TEXT {44}\#r\#n"#
                + #"\#r\#n--------------030308070208000400050907--\#r\#n)\#r\#n"#
        )

        var parser = CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            let c2_6 = try parser.parseCommandStream(buffer: &buffer)
            let c2_7 = try parser.parseCommandStream(buffer: &buffer)
            let c2_8 = try parser.parseCommandStream(buffer: &buffer)
            let c2_9 = try parser.parseCommandStream(buffer: &buffer)
            let c2_10 = try parser.parseCommandStream(buffer: &buffer)
            let c2_11 = try parser.parseCommandStream(buffer: &buffer)
            let c2_12 = try parser.parseCommandStream(buffer: &buffer)
            let c2_13 = try parser.parseCommandStream(buffer: &buffer)
            let c2_14 = try parser.parseCommandStream(buffer: &buffer)
            let c2_15 = try parser.parseCommandStream(buffer: &buffer)
            let c2_16 = try parser.parseCommandStream(buffer: &buffer)
            let c2_17 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(
                c1,
                SynchronizedCommand(.tagged(TaggedCommand(tag: "1", command: .noop)), numberOfSynchronisingLiterals: 3)
            )
            XCTAssertEqual(c2_1, SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(
                c2_2,
                SynchronizedCommand(
                    .append(
                        .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:]))
                    )
                )
            )
            XCTAssertEqual(
                c2_3,
                SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
            )
            XCTAssertEqual(c2_4, SynchronizedCommand(.append(.catenateData(.begin(size: 42)))))
            XCTAssertEqual(
                c2_5,
                SynchronizedCommand(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907\r\n"))))
            )
            XCTAssertEqual(c2_6, SynchronizedCommand(.append(.catenateData(.end))))
            XCTAssertEqual(
                c2_7,
                SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME")))
            )
            XCTAssertEqual(
                c2_8,
                SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1")))
            )
            XCTAssertEqual(c2_9, SynchronizedCommand(.append(.catenateData(.begin(size: 42)))))
            XCTAssertEqual(
                c2_10,
                SynchronizedCommand(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907\r\n"))))
            )
            XCTAssertEqual(c2_11, SynchronizedCommand(.append(.catenateData(.end))))
            XCTAssertEqual(c2_12, SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=30"))))
            XCTAssertEqual(c2_13, SynchronizedCommand(.append(.catenateData(.begin(size: 44)))))
            XCTAssertEqual(
                c2_14,
                SynchronizedCommand(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907--\r\n"))))
            )
            XCTAssertEqual(c2_15, SynchronizedCommand(.append(.catenateData(.end))))
            XCTAssertEqual(c2_16, SynchronizedCommand(.append(.endCatenate)))
            XCTAssertEqual(c2_17, SynchronizedCommand(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCommandToStreamToCommand_catenateShortExample() {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()
        do {
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c2_1, SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(
                c2_2,
                SynchronizedCommand(
                    .append(
                        .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:]))
                    )
                )
            )
            XCTAssertEqual(
                c2_3,
                SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
            )
            XCTAssertEqual(c2_4, SynchronizedCommand(.append(.endCatenate)))
            XCTAssertEqual(c2_5, SynchronizedCommand(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCatenate_failsToParseWithExtraSpace() {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE ( URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()
        XCTAssertNoThrow(try parser.parseCommandStream(buffer: &buffer))  // .append(.start)
        XCTAssertNoThrow(try parser.parseCommandStream(buffer: &buffer))  // .append(.beginCatenate)
        XCTAssertThrowsError(try parser.parseCommandStream(buffer: &buffer))
    }

    func testCommandToStreamToCommand_catenateAndOptions() {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) EXTENSION (extdata) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()
        do {
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c2_1, SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(
                c2_2,
                SynchronizedCommand(
                    .append(
                        .beginCatenate(
                            options: .init(
                                flagList: [.seen, .draft, .keyword(.mdnSent)],
                                extensions: ["EXTENSION": .comp(["extdata"])]
                            )
                        )
                    )
                )
            )
            XCTAssertEqual(
                c2_3,
                SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
            )
            XCTAssertEqual(c2_4, SynchronizedCommand(.append(.endCatenate)))
            XCTAssertEqual(c2_5, SynchronizedCommand(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testCommandToStreamToCommand_catenateAndOptions_weirdCasing() {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) EXTENSION (extdata) cAtEnAtE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()
        do {
            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            let c2_3 = try parser.parseCommandStream(buffer: &buffer)
            let c2_4 = try parser.parseCommandStream(buffer: &buffer)
            let c2_5 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c2_1, SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
            XCTAssertEqual(
                c2_2,
                SynchronizedCommand(
                    .append(
                        .beginCatenate(
                            options: .init(
                                flagList: [.seen, .draft, .keyword(.mdnSent)],
                                extensions: ["EXTENSION": .comp(["extdata"])]
                            )
                        )
                    )
                )
            )
            XCTAssertEqual(
                c2_3,
                SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
            )
            XCTAssertEqual(c2_4, SynchronizedCommand(.append(.endCatenate)))
            XCTAssertEqual(c2_5, SynchronizedCommand(.append(.finish)))
        } catch {
            XCTFail("\(error)")
        }
    }

    func testIdle() {
        // 1 NOOP
        // 2 IDLE\r\nDONE\r\n
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 IDLE\r\nDONE\r\n3 NOOP\r\n"

        var parser = CommandParser()
        do {
            let c1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c1, SynchronizedCommand(.tagged(TaggedCommand(tag: "1", command: .noop))))
            XCTAssertEqual(parser.mode, .lines)

            let c2_1 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_1, SynchronizedCommand(.tagged(TaggedCommand(tag: "2", command: .idleStart))))
            XCTAssertEqual(parser.mode, .idle)

            let c2_2 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(c2_2, SynchronizedCommand(CommandStreamPart.idleDone))
            XCTAssertEqual(parser.mode, .lines)

            let c3 = try parser.parseCommandStream(buffer: &buffer)
            XCTAssertEqual(buffer.readableBytes, 0)
            XCTAssertEqual(c3, SynchronizedCommand(.tagged(TaggedCommand(tag: "3", command: .noop))))
            XCTAssertEqual(parser.mode, .lines)
        } catch {
            XCTFail("\(error)")
        }
    }
}
