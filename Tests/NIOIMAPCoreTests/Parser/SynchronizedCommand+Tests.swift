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
import Testing

/// Integration tests for `SynchronizedCommand` parsing via `CommandParser.parseCommandStream`.
///
/// These tests verify that the command parser correctly produces `SynchronizedCommand` values
/// when parsing various IMAP command sequences, including streaming operations like APPEND,
/// CATENATE, and IDLE.
@Suite("SynchronizedCommand")
struct SynchronizedCommandTests {
    // MARK: - Basic Command Streaming

    @Test func `command stream with NOOP, APPEND with literal, and NOOP`() throws {
        // 1 NOOP
        // 2 APPEND INBOX {10}\r\n0123456789
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 APPEND INBOX {10}\r\n0123456789\r\n3 NOOP\r\n"

        var parser = CommandParser()

        let c1 = try parser.parseCommandStream(buffer: &buffer)
        let c2_1 = try parser.parseCommandStream(buffer: &buffer)
        let c2_2 = try parser.parseCommandStream(buffer: &buffer)
        let c2_3 = try parser.parseCommandStream(buffer: &buffer)
        let c2_4 = try parser.parseCommandStream(buffer: &buffer)
        let c2_5 = try parser.parseCommandStream(buffer: &buffer)
        let c3 = try parser.parseCommandStream(buffer: &buffer)

        #expect(buffer.readableBytes == 0)
        #expect(
            c1
                == SynchronizedCommand(
                    .tagged(TaggedCommand(tag: "1", command: .noop)),
                    numberOfSynchronisingLiterals: 1
                )
        )
        #expect(c2_1 == SynchronizedCommand(.append(.start(tag: "2", appendingTo: .inbox))))
        #expect(
            c2_2
                == SynchronizedCommand(
                    .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 10))))
                )
        )
        #expect(c2_3 == SynchronizedCommand(.append(.messageBytes("0123456789"))))
        #expect(c2_4 == SynchronizedCommand(.append(.endMessage)))
        #expect(c2_5 == SynchronizedCommand(.append(.finish)))
        #expect(c3 == SynchronizedCommand(.tagged(TaggedCommand(tag: "3", command: .noop))))
    }

    // MARK: - CATENATE Command Tests

    @Test func `CATENATE with multiple URL and TEXT parts`() throws {
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

        #expect(buffer.readableBytes == 0)
        #expect(
            c1
                == SynchronizedCommand(
                    .tagged(TaggedCommand(tag: "1", command: .noop)),
                    numberOfSynchronisingLiterals: 3
                )
        )
        #expect(c2_1 == SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
        #expect(
            c2_2
                == SynchronizedCommand(
                    .append(
                        .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:]))
                    )
                )
        )
        #expect(
            c2_3 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
        )
        #expect(c2_4 == SynchronizedCommand(.append(.catenateData(.begin(size: 42)))))
        #expect(
            c2_5
                == SynchronizedCommand(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907\r\n"))))
        )
        #expect(c2_6 == SynchronizedCommand(.append(.catenateData(.end))))
        #expect(
            c2_7 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME")))
        )
        #expect(
            c2_8 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1")))
        )
        #expect(c2_9 == SynchronizedCommand(.append(.catenateData(.begin(size: 42)))))
        #expect(
            c2_10
                == SynchronizedCommand(.append(.catenateData(.bytes("\r\n--------------030308070208000400050907\r\n"))))
        )
        #expect(c2_11 == SynchronizedCommand(.append(.catenateData(.end))))
        #expect(c2_12 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=30"))))
        #expect(c2_13 == SynchronizedCommand(.append(.catenateData(.begin(size: 44)))))
        #expect(
            c2_14
                == SynchronizedCommand(
                    .append(.catenateData(.bytes("\r\n--------------030308070208000400050907--\r\n")))
                )
        )
        #expect(c2_15 == SynchronizedCommand(.append(.catenateData(.end))))
        #expect(c2_16 == SynchronizedCommand(.append(.endCatenate)))
        #expect(c2_17 == SynchronizedCommand(.append(.finish)))
    }

    @Test func `CATENATE with single URL part`() throws {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()

        let c2_1 = try parser.parseCommandStream(buffer: &buffer)
        let c2_2 = try parser.parseCommandStream(buffer: &buffer)
        let c2_3 = try parser.parseCommandStream(buffer: &buffer)
        let c2_4 = try parser.parseCommandStream(buffer: &buffer)
        let c2_5 = try parser.parseCommandStream(buffer: &buffer)

        #expect(buffer.readableBytes == 0)
        #expect(c2_1 == SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
        #expect(
            c2_2
                == SynchronizedCommand(
                    .append(
                        .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:]))
                    )
                )
        )
        #expect(
            c2_3 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
        )
        #expect(c2_4 == SynchronizedCommand(.append(.endCatenate)))
        #expect(c2_5 == SynchronizedCommand(.append(.finish)))
    }

    @Test func `CATENATE fails to parse with extra space after opening parenthesis`() throws {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE ( URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()
        #expect(throws: Never.self) { try parser.parseCommandStream(buffer: &buffer) }  // .append(.start)
        #expect(throws: Never.self) { try parser.parseCommandStream(buffer: &buffer) }  // .append(.beginCatenate)
        #expect(throws: (any Error).self) { try parser.parseCommandStream(buffer: &buffer) }
    }

    @Test func `CATENATE with extension options`() throws {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) EXTENSION (extdata) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()

        let c2_1 = try parser.parseCommandStream(buffer: &buffer)
        let c2_2 = try parser.parseCommandStream(buffer: &buffer)
        let c2_3 = try parser.parseCommandStream(buffer: &buffer)
        let c2_4 = try parser.parseCommandStream(buffer: &buffer)
        let c2_5 = try parser.parseCommandStream(buffer: &buffer)

        #expect(buffer.readableBytes == 0)
        #expect(c2_1 == SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
        #expect(
            c2_2
                == SynchronizedCommand(
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
        #expect(
            c2_3 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
        )
        #expect(c2_4 == SynchronizedCommand(.append(.endCatenate)))
        #expect(c2_5 == SynchronizedCommand(.append(.finish)))
    }

    @Test func `CATENATE with extension options and mixed case keyword`() throws {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) EXTENSION (extdata) cAtEnAtE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()

        let c2_1 = try parser.parseCommandStream(buffer: &buffer)
        let c2_2 = try parser.parseCommandStream(buffer: &buffer)
        let c2_3 = try parser.parseCommandStream(buffer: &buffer)
        let c2_4 = try parser.parseCommandStream(buffer: &buffer)
        let c2_5 = try parser.parseCommandStream(buffer: &buffer)

        #expect(buffer.readableBytes == 0)
        #expect(c2_1 == SynchronizedCommand(.append(.start(tag: "A003", appendingTo: MailboxName("Drafts")))))
        #expect(
            c2_2
                == SynchronizedCommand(
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
        #expect(
            c2_3 == SynchronizedCommand(.append(.catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")))
        )
        #expect(c2_4 == SynchronizedCommand(.append(.endCatenate)))
        #expect(c2_5 == SynchronizedCommand(.append(.finish)))
    }

    // MARK: - IDLE Command Tests

    @Test func `IDLE command lifecycle with mode transitions`() throws {
        // 1 NOOP
        // 2 IDLE\r\nDONE\r\n
        // 3 NOOP
        var buffer: ByteBuffer = "1 NOOP\r\n2 IDLE\r\nDONE\r\n3 NOOP\r\n"

        var parser = CommandParser()

        let c1 = try parser.parseCommandStream(buffer: &buffer)
        #expect(c1 == SynchronizedCommand(.tagged(TaggedCommand(tag: "1", command: .noop))))
        #expect(parser.mode == .lines)

        let c2_1 = try parser.parseCommandStream(buffer: &buffer)
        #expect(c2_1 == SynchronizedCommand(.tagged(TaggedCommand(tag: "2", command: .idleStart))))
        #expect(parser.mode == .idle)

        let c2_2 = try parser.parseCommandStream(buffer: &buffer)
        #expect(c2_2 == SynchronizedCommand(CommandStreamPart.idleDone))
        #expect(parser.mode == .lines)

        let c3 = try parser.parseCommandStream(buffer: &buffer)
        #expect(buffer.readableBytes == 0)
        #expect(c3 == SynchronizedCommand(.tagged(TaggedCommand(tag: "3", command: .noop))))
        #expect(parser.mode == .lines)
    }
}
