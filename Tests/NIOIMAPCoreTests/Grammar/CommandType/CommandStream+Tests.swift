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
import Testing

@Suite("CommandStreamPart")
private struct CommandStreamTests {
    @Test(
        arguments: [
            CommandEncodeFixture.commandStream(.append(.start(tag: "1", appendingTo: .inbox)), "1 APPEND \"INBOX\""),
            CommandEncodeFixture.commandStream(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 3)))),
                " {3}\r\n"
            ),
            CommandEncodeFixture.commandStream(
                .append(
                    .beginMessage(
                        message: .init(
                            options: .init(flagList: [.seen, .deleted], extensions: [:]),
                            data: .init(byteCount: 3)
                        )
                    )
                ),
                " (\\Seen \\Deleted) {3}\r\n"
            ),
            CommandEncodeFixture.commandStream(.append(.messageBytes("123")), "123"),
            CommandEncodeFixture.commandStream(.append(.endMessage), ""),
            CommandEncodeFixture.commandStream(.append(.finish), "\r\n"),
            CommandEncodeFixture.commandStream(.tagged(.init(tag: "1", command: .noop)), "1 NOOP\r\n"),
            CommandEncodeFixture.commandStream(.idleDone, "DONE\r\n"),
            CommandEncodeFixture.commandStream(.continuationResponse("test"), "dGVzdA==\r\n"),
        ] as [CommandEncodeFixture<CommandStreamPart>]
    )
    func encode(_ fixture: CommandEncodeFixture<CommandStreamPart>) {
        fixture.checkEncoding()
    }

    @Test("continuation synchronizing literal") func continuationSynchronizingLiteral() throws {
        let parts: [AppendCommand] = [
            .start(tag: "1", appendingTo: .inbox),
            .beginMessage(message: .init(options: .none, data: .init(byteCount: 7))),
            .messageBytes("Foo Bar"),
            .endMessage,
            .finish,
        ]

        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [], loggingMode: false)
        parts.map { CommandStreamPart.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        let encodedCommand = buffer.buffer.nextChunk()
        #expect(String(buffer: encodedCommand.bytes) == #"1 APPEND "INBOX" {7}\#r\#n"#)
        guard encodedCommand.waitForContinuation else {
            Issue.record("Should have had a continuation.")
            return
        }
        let continuation = buffer.buffer.nextChunk()
        #expect(String(buffer: continuation.bytes) == "Foo Bar\r\n")
        #expect(!continuation.waitForContinuation, "Should not have additional continuations.")
    }

    @Test("continuation non-synchronizing literal plus") func continuationNonSynchronizingLiteralPlus() throws {
        let parts: [AppendCommand] = [
            .start(tag: "1", appendingTo: .inbox),
            .beginMessage(message: .init(options: .none, data: .init(byteCount: 3))),
            .messageBytes("abc"),
            .endMessage,
            .finish,
        ]

        var options = CommandEncodingOptions()
        options.useNonSynchronizingLiteralPlus = true
        var buffer = CommandEncodeBuffer(buffer: "", options: options, loggingMode: false)
        parts.map { CommandStreamPart.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        let encodedCommand = buffer.buffer.nextChunk()
        #expect(String(buffer: encodedCommand.bytes) == #"1 APPEND "INBOX" {3+}\#r\#nabc\#r\#n"#)
        guard !encodedCommand.waitForContinuation else {
            Issue.record("Should not have had a continuation.")
            return
        }
    }

    @Test("catenate example one with synchronizing literals") func catenateExampleOneWithSynchronizingLiterals() throws {
        let parts: [AppendCommand] = [
            .start(tag: "A003", appendingTo: MailboxName("Drafts")),
            .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:])),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"),
            .catenateData(.begin(size: 42)),
            .catenateData(.bytes("\r\n--------------030308070208000400050907\r\n")),
            .catenateData(.end),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME"),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1"),
            .catenateData(.begin(size: 42)),
            .catenateData(.bytes("\r\n--------------030308070208000400050907\r\n")),
            .catenateData(.end),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=30"),
            .catenateData(.begin(size: 44)),
            .catenateData(.bytes("\r\n--------------030308070208000400050907--\r\n")),
            .catenateData(.end),
            .endCatenate,
            .finish,
        ]

        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [], loggingMode: false)
        parts.map { CommandStreamPart.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        var encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes)
                == #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {42}\#r\#n"#
        )
        guard encodedCommand.waitForContinuation else {
            Issue.record("Should have had a continuation.")
            return
        }

        encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes)
                == #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME" URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1" TEXT {42}\#r\#n"#
        )
        guard encodedCommand.waitForContinuation else {
            Issue.record("Should have had a continuation.")
            return
        }

        encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes)
                == #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=30" TEXT {44}\#r\#n"#
        )
        guard encodedCommand.waitForContinuation else {
            Issue.record("Should have had a continuation.")
            return
        }

        encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes) == #"\#r\#n--------------030308070208000400050907--\#r\#n)\#r\#n"#
        )
        #expect(!encodedCommand.waitForContinuation, "Should not have additional continuations.")
    }

    @Test("catenate example one with non-synchronizing literals") func catenateExampleOneWithNonSynchronizingLiterals() throws {
        let parts: [AppendCommand] = [
            .start(tag: "A003", appendingTo: MailboxName("Drafts")),
            .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:])),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"),
            .catenateData(.begin(size: 42)),
            .catenateData(.bytes("\r\n--------------030308070208000400050907\r\n")),
            .catenateData(.end),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME"),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1"),
            .catenateData(.begin(size: 42)),
            .catenateData(.bytes("\r\n--------------030308070208000400050907\r\n")),
            .catenateData(.end),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=30"),
            .catenateData(.begin(size: 44)),
            .catenateData(.bytes("\r\n--------------030308070208000400050907--\r\n")),
            .catenateData(.end),
            .endCatenate,
            .finish,
        ]

        var options = CommandEncodingOptions()
        options.useNonSynchronizingLiteralPlus = true
        var buffer = CommandEncodeBuffer(buffer: "", options: options, loggingMode: false)
        parts.map { CommandStreamPart.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        let encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes)
                == #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {42+}\#r\#n"#
                + #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME" URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1" TEXT {42+}\#r\#n"#
                + #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=30" TEXT {44+}\#r\#n"#
                + #"\#r\#n--------------030308070208000400050907--\#r\#n)\#r\#n"#
        )
        #expect(!encodedCommand.waitForContinuation, "Should not have additional continuations.")
    }

    @Test("catenate sequential commands") func catenateSequentialCommands() throws {
        let parts: [AppendCommand] = [
            .start(tag: "A003", appendingTo: MailboxName("Drafts")),
            .beginCatenate(options: .init(flagList: [.seen, .draft, .keyword(.mdnSent)], extensions: [:])),
            .catenateURL("/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER"),
            .catenateData(.begin(size: 5)),
            .catenateData(.bytes("hello")),
            .catenateData(.end),
            .endCatenate,
            .finish,
        ]

        // Apply parts twice.
        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [], loggingMode: false)
        (parts + parts).map { CommandStreamPart.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        var encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes)
                == #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {5}\#r\#n"#
        )
        guard encodedCommand.waitForContinuation else {
            Issue.record("Should have had a continuation.")
            return
        }

        encodedCommand = buffer.buffer.nextChunk()
        #expect(
            String(buffer: encodedCommand.bytes)
                == #"hello)\#r\#nA003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {5}\#r\#n"#
        )
        guard encodedCommand.waitForContinuation else {
            Issue.record("Should have had a continuation.")
            return
        }

        encodedCommand = buffer.buffer.nextChunk()
        #expect(String(buffer: encodedCommand.bytes) == #"hello)\#r\#n"#)
        #expect(!encodedCommand.waitForContinuation, "Should not have additional continuations.")
    }

    @Test("description without PII", arguments: [
        PIIFixture(
            input: .append(.start(tag: "1", appendingTo: .inbox)),
            expected: "1 APPEND \"∅\""
        ),
        PIIFixture(
            input: .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 3)))),
            expected: " {3}\r\n"
        ),
        PIIFixture(
            input: .append(
                .beginMessage(
                    message: .init(
                        options: .init(flagList: [.seen, .deleted], extensions: [:]),
                        data: .init(byteCount: 3)
                    )
                )
            ),
            expected: " (\\Seen \\Deleted) {3}\r\n"
        ),
        PIIFixture(
            input: .tagged(.init(tag: "1", command: .noop)),
            expected: "1 NOOP\r\n"
        ),
        PIIFixture(
            input: .idleDone,
            expected: "DONE\r\n"
        ),
        PIIFixture(
            input: .continuationResponse("test"),
            expected: "[8 bytes]\r\n"
        ),
    ])
    func descriptionWithoutPII(_ fixture: PIIFixture) {
        #expect(CommandStreamPart.descriptionWithoutPII([fixture.input]) == fixture.expected)
    }
}

// MARK: -

extension CommandEncodeFixture<CommandStreamPart> {
    fileprivate static func commandStream(
        _ input: CommandStreamPart,
        _ expectedString: String,
        options: CommandEncodingOptions = CommandEncodingOptions()
    ) -> Self {
        CommandEncodeFixture(
            input: input,
            options: options,
            expectedString: expectedString,
            encoder: { $0.writeCommandStream($1) }
        )
    }
}

private struct PIIFixture: Sendable, CustomTestStringConvertible {
    let input: CommandStreamPart
    let expected: String

    var testDescription: String { expected.mappingControlPictures() }
}
