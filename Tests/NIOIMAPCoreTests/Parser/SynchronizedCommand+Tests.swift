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

    @Test("command stream with NOOP, APPEND with literal, and NOOP")
    func commandStreamWithNoopAppendWithLiteralAndNoop() throws {
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

    @Test("CATENATE with multiple URL and TEXT parts")
    func catenateWithMultipleUrlAndTextParts() throws {
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

    @Test("CATENATE with single URL part")
    func catenateWithSingleUrlPart() throws {
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

    @Test("CATENATE fails to parse with extra space after opening parenthesis")
    func catenateFailsToParseWithExtraSpaceAfterOpeningParenthesis() throws {
        var buffer = ByteBuffer(
            string:
                #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE ( URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER")\#r\#n"#
        )

        var parser = CommandParser()
        #expect(throws: Never.self) { try parser.parseCommandStream(buffer: &buffer) }  // .append(.start)
        #expect(throws: Never.self) { try parser.parseCommandStream(buffer: &buffer) }  // .append(.beginCatenate)
        #expect(throws: (any Error).self) { try parser.parseCommandStream(buffer: &buffer) }
    }

    @Test("CATENATE with extension options")
    func catenateWithExtensionOptions() throws {
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

    @Test("CATENATE with extension options and mixed case keyword")
    func catenateWithExtensionOptionsAndMixedCaseKeyword() throws {
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

    @Test("CATENATE with non-synchronizing literal TEXT part")
    func catenateWithNonSynchronizingLiteralTextPart() throws {
        // Uses TEXT {N+}\r\n (non-synchronizing literal with '+')
        var buffer = ByteBuffer(
            string: "A1 APPEND Drafts CATENATE (TEXT {5+}\r\nhello)\r\n"
        )

        var parser = CommandParser()

        let c1 = try parser.parseCommandStream(buffer: &buffer)
        let c2 = try parser.parseCommandStream(buffer: &buffer)
        let c3 = try parser.parseCommandStream(buffer: &buffer)
        let c4 = try parser.parseCommandStream(buffer: &buffer)
        let c5 = try parser.parseCommandStream(buffer: &buffer)
        let c6 = try parser.parseCommandStream(buffer: &buffer)
        let c7 = try parser.parseCommandStream(buffer: &buffer)

        #expect(buffer.readableBytes == 0)
        #expect(c1 == SynchronizedCommand(.append(.start(tag: "A1", appendingTo: MailboxName("Drafts")))))
        #expect(c2 == SynchronizedCommand(.append(.beginCatenate(options: .none))))
        #expect(c3 == SynchronizedCommand(.append(.catenateData(.begin(size: 5)))))
        #expect(c4 == SynchronizedCommand(.append(.catenateData(.bytes("hello")))))
        #expect(c5 == SynchronizedCommand(.append(.catenateData(.end))))
        #expect(c6 == SynchronizedCommand(.append(.endCatenate)))
        #expect(c7 == SynchronizedCommand(.append(.finish)))
    }

    // MARK: - IDLE Command Tests

    // MARK: - Streaming byte chunking

    @Test("partial APPEND streaming bytes triggers intermediate streaming mode")
    func partialAppendStreamingBytesTriggersIntermediateStreamingMode() throws {
        var parser = CommandParser()
        // Start APPEND with 10-byte non-synchronising literal, but only provide 5 bytes
        var buf = ByteBuffer("1 APPEND INBOX {10+}\r\nHello")

        let c1 = try parser.parseCommandStream(buffer: &buf)
        #expect(c1 == SynchronizedCommand(.append(.start(tag: "1", appendingTo: .inbox))))

        let c2 = try parser.parseCommandStream(buffer: &buf)
        #expect(
            c2
                == SynchronizedCommand(
                    .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 10))))
                )
        )
        #expect(parser.mode == .streamingBytes(10))

        // Only 5 bytes available — should enter the else branch and leave 5 remaining
        let c3 = try parser.parseCommandStream(buffer: &buf)
        #expect(c3 == SynchronizedCommand(.append(.messageBytes(ByteBuffer(string: "Hello")))))
        #expect(parser.mode == .streamingBytes(5))

        // Provide the remaining 5 bytes
        buf.writeString("World")
        let c4 = try parser.parseCommandStream(buffer: &buf)
        #expect(c4 == SynchronizedCommand(.append(.messageBytes(ByteBuffer(string: "World")))))
        #expect(parser.mode == .streamingEnd)

        buf.writeString("\r\n")
        let c5 = try parser.parseCommandStream(buffer: &buf)
        #expect(c5 == SynchronizedCommand(.append(.endMessage)))

        let c6 = try parser.parseCommandStream(buffer: &buf)
        #expect(c6 == SynchronizedCommand(.append(.finish)))
    }

    @Test("partial CATENATE streaming bytes triggers intermediate streaming mode")
    func partialCatenateStreamingBytesTriggersIntermediateStreamingMode() throws {
        var parser = CommandParser()
        // CATENATE with 5-byte TEXT literal but only 3 bytes provided initially
        var buf = ByteBuffer("A1 APPEND Drafts CATENATE (TEXT {5+}\r\nhel")

        let c1 = try parser.parseCommandStream(buffer: &buf)
        #expect(c1 == SynchronizedCommand(.append(.start(tag: "A1", appendingTo: MailboxName("Drafts")))))

        let c2 = try parser.parseCommandStream(buffer: &buf)
        #expect(c2 == SynchronizedCommand(.append(.beginCatenate(options: .none))))

        let c3 = try parser.parseCommandStream(buffer: &buf)
        #expect(c3 == SynchronizedCommand(.append(.catenateData(.begin(size: 5)))))

        // Only 3 of 5 bytes available — enters the else branch
        let c4 = try parser.parseCommandStream(buffer: &buf)
        #expect(c4 == SynchronizedCommand(.append(.catenateData(.bytes(ByteBuffer(string: "hel"))))))
        #expect(parser.mode == .streamingCatenateBytes(2))

        // Provide the remaining 2 bytes
        buf.writeString("lo")
        let c5 = try parser.parseCommandStream(buffer: &buf)
        #expect(c5 == SynchronizedCommand(.append(.catenateData(.bytes(ByteBuffer(string: "lo"))))))
        #expect(parser.mode == .streamingCatenateEnd)

        buf.writeString(")\r\n")
        let c6 = try parser.parseCommandStream(buffer: &buf)
        #expect(c6 == SynchronizedCommand(.append(.catenateData(.end))))

        let c7 = try parser.parseCommandStream(buffer: &buf)
        #expect(c7 == SynchronizedCommand(.append(.endCatenate)))

        let c8 = try parser.parseCommandStream(buffer: &buf)
        #expect(c8 == SynchronizedCommand(.append(.finish)))
    }

    // MARK: - Incomplete input and synchronising literals

    @Test("incomplete command with no synchronising literals returns nil")
    func incompleteCommandWithNoSynchronisingLiteralsReturnsNil() throws {
        // Buffer has bytes but no complete command line yet — no newline found
        var parser = CommandParser()
        var buf = ByteBuffer("1 NOO")
        let result = try parser.parseCommandStream(buffer: &buf)
        #expect(result == nil)
    }

    @Test("synchronising literal without literal data returns SynchronizedCommand with count only")
    func synchronisingLiteralWithoutLiteralDataReturnsSynchronizedCommandWithCountOnly() throws {
        // The framing parser finds 1 synchronising literal but the literal bytes are absent.
        // parseCommand() returns nil (IncompleteMessage), but synchronizingLiteralCount == 1.
        var parser = CommandParser()
        var buf = ByteBuffer("1 LOGIN {5}\r\n")
        let result = try parser.parseCommandStream(buffer: &buf)
        #expect(result == SynchronizedCommand(numberOfSynchronisingLiterals: 1))
    }

    // MARK: - Continuation response

    @Test("authentication continuation response is parsed from base64 line")
    func authenticationContinuationResponseIsParsedFromBase64Line() throws {
        // A base64-encoded line (not a tagged command or APPEND) is parsed as a
        // continuationResponse via parseAuthenticationChallengeResponse.
        var parser = CommandParser()
        // "AHRlc3R1c2VyAHRlc3RwYXNz" is base64 for "\0testuser\0testpass"
        var buf = ByteBuffer("AHRlc3R1c2VyAHRlc3RwYXNz\r\n")
        let result = try parser.parseCommandStream(buffer: &buf)
        guard case .continuationResponse = result?.commandPart else {
            Issue.record("Expected continuationResponse, got \(String(describing: result))")
            return
        }
        #expect(buf.readableBytes == 0)
    }

    // MARK: - Incomplete CRLF in waitingForMessage mode

    @Test("invalid bytes in waitingForMessage triggers buffer restore and rethrow")
    func invalidBytesInWaitingForMessageTriggersBufferRestoreAndRethrow() throws {
        // After all message bytes are streamed, the parser is in .waitingForMessage.
        // If the next line is neither a new message header nor a CRLF (e.g. garbage text),
        // parseAppendOrCatenateMessage throws ParserError, then parseNewline also fails
        // on the non-newline byte — triggering the buffer-restore path (line 231 in
        // CommandParser.swift) before rethrowing.
        var parser = CommandParser()
        var buf = ByteBuffer("1 APPEND INBOX {0+}\r\ngarbage\r\n")

        let c1 = try parser.parseCommandStream(buffer: &buf)
        #expect(c1 == SynchronizedCommand(.append(.start(tag: "1", appendingTo: .inbox))))

        let c2 = try parser.parseCommandStream(buffer: &buf)
        #expect(
            c2 == SynchronizedCommand(.append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 0)))))
        )

        let c3 = try parser.parseCommandStream(buffer: &buf)  // .messageBytes(empty) — 0-byte literal
        #expect(c3 == SynchronizedCommand(.append(.messageBytes(ByteBuffer()))))

        let c4 = try parser.parseCommandStream(buffer: &buf)  // .endMessage, mode = .waitingForMessage
        #expect(c4 == SynchronizedCommand(.append(.endMessage)))

        // "garbage" is not a valid append-continue token or newline; parseNewline fails on "g",
        // which triggers the buffer restore (line 231) and a rethrow.
        #expect(throws: (any Error).self) {
            try parser.parseCommandStream(buffer: &buf)
        }
    }

    // MARK: - IDLE Command Tests

    @Test("IDLE command lifecycle with mode transitions")
    func idleCommandLifecycleWithModeTransitions() throws {
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
