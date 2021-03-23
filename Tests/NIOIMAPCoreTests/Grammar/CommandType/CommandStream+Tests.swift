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

class CommandStream_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CommandStream_Tests {
    func testEncode() {
        let inputs: [(CommandStream, String, UInt)] = [
            (.append(.start(tag: "1", appendingTo: .inbox)), "1 APPEND \"INBOX\"", #line),
            (
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 3)))),
                " {3}\r\n",
                #line
            ),
            (
                .append(.beginMessage(message: .init(options: .init(flagList: [.seen, .deleted], extensions: [:]), data: .init(byteCount: 3)))),
                " (\\Seen \\Deleted) {3}\r\n",
                #line
            ),
            (.append(.messageBytes("123")), "123", #line),
            (.append(.endMessage), "", #line), // dummy command, we don't expect anything
            (.append(.finish), "\r\n", #line),
            (.command(.init(tag: "1", command: .noop)), "1 NOOP\r\n", #line),
            (.idleDone, "DONE\r\n", #line),
            (.continuationResponse("test"), "\r\ntest", #line),
        ]

        for (command, expected, line) in inputs {
            var commandEncodeBuffer = CommandEncodeBuffer(buffer: "", capabilities: [])
            commandEncodeBuffer.writeCommandStream(command)
            XCTAssertEqual(String(buffer: commandEncodeBuffer._buffer._buffer), expected, line: line)
        }
    }

    func testContinuation_synchronizing() throws {
        let parts: [AppendCommand] = [
            .start(tag: "1", appendingTo: .inbox),
            .beginMessage(message: .init(options: .none, data: .init(byteCount: 7))),
            .messageBytes("Foo Bar"),
            .endMessage,
            .finish,
        ]

        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [])
        parts.map { CommandStream.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        let encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"1 APPEND "INBOX" {7}\#r\#n"#)
        guard encodedCommand._waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }
        let continuation = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: continuation._bytes), "Foo Bar\r\n")
        XCTAssertFalse(continuation._waitForContinuation, "Should not have additional continuations.")
    }

    func testContinuation_nonSynchronizing() throws {
        let parts: [AppendCommand] = [
            .start(tag: "1", appendingTo: .inbox),
            .beginMessage(message: .init(options: .none, data: .init(byteCount: 3))),
            .messageBytes("abc"),
            .endMessage,
            .finish,
        ]

        var options = CommandEncodingOptions()
        options.useNonSynchronizingLiteralPlus = true
        var buffer = CommandEncodeBuffer(buffer: "", options: options)
        parts.map { CommandStream.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        let encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"1 APPEND "INBOX" {3+}\#r\#nabc\#r\#n"#)
        guard !encodedCommand._waitForContinuation else {
            XCTFail("Should not have had a continuation.")
            return
        }
    }

    func testCatenate_exampleOne() throws {
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

        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [])
        parts.map { CommandStream.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        var encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {42}\#r\#n"#)
        guard encodedCommand._waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }

        encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME" URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1" TEXT {42}\#r\#n"#)
        guard encodedCommand._waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }

        encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=30" TEXT {44}\#r\#n"#)
        guard encodedCommand._waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }

        encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"\#r\#n--------------030308070208000400050907--\#r\#n)\#r\#n"#)
        XCTAssertFalse(encodedCommand._waitForContinuation, "Should not have additional continuations.")
    }

    func testCatenate_exampleOne_nonSynchronizing() throws {
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
        var buffer = CommandEncodeBuffer(buffer: "", options: options)
        parts.map { CommandStream.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        let encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(
            String(buffer: encodedCommand._bytes),
            #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {42+}\#r\#n"# +
                #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1.MIME" URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=1" TEXT {42+}\#r\#n"# +
                #"\#r\#n--------------030308070208000400050907\#r\#n URL "/Drafts;UIDVALIDITY=385759045/;UID=30" TEXT {44+}\#r\#n"# +
                #"\#r\#n--------------030308070208000400050907--\#r\#n)\#r\#n"#
        )
        XCTAssertFalse(encodedCommand._waitForContinuation, "Should not have additional continuations.")
    }

    func testCatenate_sequential() throws {
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
        var buffer = CommandEncodeBuffer(buffer: "", capabilities: [])
        (parts + parts).map { CommandStream.append($0) }.forEach {
            buffer.writeCommandStream($0)
        }

        var encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"A003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {5}\#r\#n"#)
        guard encodedCommand._waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }

        encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"hello)\#r\#nA003 APPEND "Drafts" (\Seen \Draft $MDNSent) CATENATE (URL "/Drafts;UIDVALIDITY=385759045/;UID=20/;section=HEADER" TEXT {5}\#r\#n"#)
        guard encodedCommand._waitForContinuation else {
            XCTFail("Should have had a continuation.")
            return
        }

        encodedCommand = buffer._buffer._nextChunk()
        XCTAssertEqual(String(buffer: encodedCommand._bytes), #"hello)\#r\#n"#)
        XCTAssertFalse(encodedCommand._waitForContinuation, "Should not have additional continuations.")
    }
}
