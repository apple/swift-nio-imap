//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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
import OrderedCollections
import Testing

/// APPEND parts whose arguments must be sent as synchronizing literals (RFC 3501 §4.3, §7.5):
/// the client sends `{n}\r\n`, waits for `+`, then sends the `n` bytes and the rest of the part.
@Suite("IMAPClientHandler APPEND literals")
struct AppendLiteralTests {
    /// A mailbox name with an 8-bit byte can't be quoted, so it is sent as a literal.
    @Test("APPEND to a mailbox that needs a literal waits for + and sends the name")
    func appendToLiteralMailbox() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {2}\r\n")

        let begin = helper.writeOutbound(
            .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5)))),
            wait: false
        )
        // The message literal header must wait until the server accepted the mailbox literal.
        #expect(helper.drainOutbound() == "")
        #expect(helper.outcome(of: start) == nil)

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "å {5}\r\n")

        let bytes = helper.writeOutbound(.append(.messageBytes("hello")), wait: false)
        let end = helper.writeOutbound(.append(.endMessage), wait: false)
        let finish = helper.writeOutbound(.append(.finish), wait: false)
        #expect(helper.drainOutbound() == "")

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "hello\r\n")

        helper.writeInbound("A1 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "done")))))

        for future in [start, begin, bytes, end, finish] {
            helper.expectSucceeded(future)
        }
    }

    /// A CATENATE URL too long to quote is sent as a literal.
    @Test("CATENATE with a URL that needs a literal waits for + and sends the URL")
    func catenateLiteralURL() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }

        // 90 bytes; the literal header below must match.
        let url = "imap://user@example.com/INBOX;UIDVALIDITY=1234567890/;UID=20/;SECTION=1.2.3.4.5.6.7.8.MIME"

        helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .inbox)))
        helper.writeOutbound(.append(.beginCatenate(options: .init())))
        #expect(helper.drainOutbound() == "A1 APPEND \"INBOX\" CATENATE (")

        let urlPart = helper.writeOutbound(.append(.catenateURL(Array(url.utf8))), wait: false)
        #expect(helper.drainOutbound() == "URL {90}\r\n")

        let endCatenate = helper.writeOutbound(.append(.endCatenate), wait: false)
        let finish = helper.writeOutbound(.append(.finish), wait: false)
        #expect(helper.drainOutbound() == "")

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "\(url))\r\n")

        helper.writeInbound("A1 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "done")))))

        for future in [urlPart, endCatenate, finish] {
            helper.expectSucceeded(future)
        }
    }

    /// A part with a literal mid-part that also ends in its own literal header: the message's.
    @Test("APPEND option that needs a literal, then the message literal")
    func appendOptionLiteralBeforeMessageLiteral() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }

        helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .inbox)))
        #expect(helper.drainOutbound() == "A1 APPEND \"INBOX\"")

        let options = AppendOptions(extensions: ["X": .comp(["å"])])
        let begin = helper.writeOutbound(
            .append(.beginMessage(message: .init(options: options, data: .init(byteCount: 5)))),
            wait: false
        )
        // `.comp` is written in double parentheses.
        #expect(helper.drainOutbound() == " X (({2}\r\n")

        let bytes = helper.writeOutbound(.append(.messageBytes("hello")), wait: false)
        #expect(helper.drainOutbound() == "")
        #expect(helper.outcome(of: begin) == nil)

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "å)) {5}\r\n")
        helper.expectSucceeded(begin)

        let end = helper.writeOutbound(.append(.endMessage), wait: false)
        let finish = helper.writeOutbound(.append(.finish), wait: false)
        #expect(helper.drainOutbound() == "")

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "hello\r\n")

        helper.writeInbound("A1 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "done")))))

        for future in [bytes, end, finish] {
            helper.expectSucceeded(future)
        }
    }

    /// Two literals before the part's end: each waits for its own `+`.
    @Test("APPEND options with two literals wait for a + each")
    func appendOptionsWithTwoLiterals() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }

        helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .inbox)))
        #expect(helper.drainOutbound() == "A1 APPEND \"INBOX\"")

        let options = AppendOptions(extensions: ["X": .comp(["å", "é"])])
        let begin = helper.writeOutbound(
            .append(.beginMessage(message: .init(options: options, data: .init(byteCount: 5)))),
            wait: false
        )
        #expect(helper.drainOutbound() == " X (({2}\r\n")

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "å {2}\r\n")
        #expect(helper.outcome(of: begin) == nil)

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "é)) {5}\r\n")
        helper.expectSucceeded(begin)

        helper.writeOutbound(.append(.messageBytes("hello")), wait: false)
        helper.writeOutbound(.append(.endMessage), wait: false)
        helper.writeOutbound(.append(.finish), wait: false)
        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "hello\r\n")

        helper.writeInbound("A1 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "done")))))
    }

    /// A zero-length literal ends the part, yet the next part must still wait for its `+`.
    @Test("APPEND to an empty mailbox sent as a literal waits for +")
    func appendToEmptyLiteralMailbox() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }
        var options = CommandEncodingOptions.rfc3501
        options.useQuotedString = false
        helper.writeOutbound(.setEncodingOptions(.fixed(options)))

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init(""))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {0}\r\n")

        let begin = helper.writeOutbound(
            .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5)))),
            wait: false
        )
        #expect(helper.drainOutbound() == "")

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == " {5}\r\n")
        helper.expectSucceeded(start)
        helper.expectSucceeded(begin)

        helper.writeOutbound(.append(.messageBytes("hello")), wait: false)
        helper.writeOutbound(.append(.endMessage), wait: false)
        helper.writeOutbound(.append(.finish), wait: false)
        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "hello\r\n")

        helper.writeInbound("A1 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "done")))))
    }

    @Test("CATENATE with an empty URL sent as a literal waits for +")
    func catenateEmptyLiteralURL() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }
        helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .inbox)))
        helper.writeOutbound(.append(.beginCatenate(options: .init())))
        #expect(helper.drainOutbound() == "A1 APPEND \"INBOX\" CATENATE (")

        var options = CommandEncodingOptions.rfc3501
        options.useQuotedString = false
        helper.writeOutbound(.setEncodingOptions(.fixed(options)))

        let urlPart = helper.writeOutbound(.append(.catenateURL("")), wait: false)
        #expect(helper.drainOutbound() == "URL {0}\r\n")

        let endCatenate = helper.writeOutbound(.append(.endCatenate), wait: false)
        helper.writeOutbound(.append(.finish), wait: false)
        #expect(helper.drainOutbound() == "")

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == ")\r\n")
        helper.expectSucceeded(urlPart)
        helper.expectSucceeded(endCatenate)

        helper.writeInbound("A1 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "done")))))
    }

    @Test("untagged response while waiting for an APPEND literal's + is forwarded")
    func untaggedWhileWaitingForLiteral() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {2}\r\n")

        helper.writeInbound("* 3 EXISTS\r\n")
        helper.expectInbound(.untagged(.mailboxData(.exists(3))))
        #expect(helper.outcome(of: start) == nil)

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "å")
        helper.expectSucceeded(start)
    }

    @Test("another command's tagged response while waiting for an APPEND literal's + is forwarded")
    func otherTaggedWhileWaitingForLiteral() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }

        helper.writeOutbound(.tagged(.init(tag: "A0", command: .noop)))
        #expect(helper.drainOutbound() == "A0 NOOP\r\n")

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {2}\r\n")

        helper.writeInbound("A0 OK done\r\n")
        helper.expectInbound(.tagged(.init(tag: "A0", state: .ok(.init(code: nil, text: "done")))))
        #expect(helper.outcome(of: start) == nil)

        helper.writeInbound("+ OK\r\n")
        #expect(helper.drainOutbound() == "å")
        helper.expectSucceeded(start)
    }

    @Test("APPEND to a mailbox that needs a literal sends it right away with LITERAL+")
    func appendToLiteralMailboxWithLiteralPlus() {
        var helper = IMAPClientHandlerTests.Helper()
        defer { helper.check() }
        helper.writeOutbound(.setEncodingOptions(.fixed(.init(capabilities: [.literalPlus]))))

        helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))))
        #expect(helper.drainOutbound() == "A1 APPEND {2+}\r\nå")

        helper.writeOutbound(.append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5)))))
        #expect(helper.drainOutbound() == " {5}\r\n")
    }

    /// RFC 3501 §7.5: the server may reject a literal with a tagged response instead of `+`.
    @Test("tagged rejection of an APPEND literal fails the part's write")
    func taggedRejectionOfLiteral() {
        var helper = IMAPClientHandlerTests.Helper()

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {2}\r\n")
        let begin = helper.writeOutbound(
            .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5)))),
            wait: false
        )

        #expect(throws: UnexpectedResponse.self) {
            try helper.channel.writeInbound(helper.buffer(string: "A1 NO too long\r\n"))
        }
        guard case .failure(let error as UnexpectedResponse) = helper.outcome(of: start) else {
            Issue.record("APPEND start should fail, not \(String(describing: helper.outcome(of: start)))")
            return
        }
        #expect(error.kind == .appendNotWaitingForTaggedResponse)
        #expect(helper.drainOutbound() == "")

        #expect(throws: Never.self) { try helper.channel.close().wait() }
        guard case .failure = helper.outcome(of: begin) else {
            Issue.record("Queued part should fail, not \(String(describing: helper.outcome(of: begin)))")
            return
        }
    }

    @Test("channel close while waiting for an APPEND literal's + fails the part's write")
    func channelCloseWhileWaitingForLiteral() {
        var helper = IMAPClientHandlerTests.Helper()

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {2}\r\n")

        #expect(throws: Never.self) { try helper.channel.close().wait() }
        guard case .failure(let error) = helper.outcome(of: start) else {
            Issue.record("APPEND start should fail, not \(String(describing: helper.outcome(of: start)))")
            return
        }
        #expect(error as? ChannelError == .ioOnClosedChannel)
    }

    /// `* BYE` is untagged: forwarded, and the part stays pending until the channel closes.
    @Test("BYE while waiting for an APPEND literal's + is forwarded; close fails the part's write")
    func byeWhileWaitingForLiteral() {
        var helper = IMAPClientHandlerTests.Helper()

        let start = helper.writeOutbound(.append(.start(tag: "A1", appendingTo: .init("å"))), wait: false)
        #expect(helper.drainOutbound() == "A1 APPEND {2}\r\n")

        helper.writeInbound("* BYE shutting down\r\n")
        helper.expectInbound(.untagged(.conditionalState(.bye(.init(code: nil, text: "shutting down")))))
        #expect(helper.outcome(of: start) == nil)
        #expect(helper.drainOutbound() == "")

        #expect(throws: Never.self) { try helper.channel.close().wait() }
        guard case .failure(let error) = helper.outcome(of: start) else {
            Issue.record("APPEND start should fail, not \(String(describing: helper.outcome(of: start)))")
            return
        }
        #expect(error as? ChannelError == .ioOnClosedChannel)
    }

    /// The parser never produces `Response.fatal`, so this drives `ClientStateMachine` directly.
    @Test("fatal response while waiting for an APPEND literal's + fails the part's write")
    func fatalWhileWaitingForLiteral() {
        let eventLoop = EmbeddedEventLoop()
        var stateMachine = ClientStateMachine(encodingOptions: .fixed(.rfc3501))
        stateMachine.handlerAdded(ByteBufferAllocator())

        let start = eventLoop.makePromise(of: Void.self)
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .init("å"))), promise: start)
        }
        guard case .appendingLiteral = stateMachine.state else {
            Issue.record("Should wait for +, not \(stateMachine.state)")
            start.succeed()
            return
        }

        // The error carries the part's promise; IMAPClientHandler fails it.
        do {
            _ = try stateMachine.receiveResponse(.fatal(.init(text: "Autologout")))
            Issue.record("A fatal response must throw")
            start.succeed()
        } catch let error as UnexpectedResponse {
            #expect(error.kind == .appendNotWaitingForTaggedResponse)
            #expect(error.activePromise?.futureResult === start.futureResult)
            start.fail(error)
        } catch {
            Issue.record("Unexpected error \(error)")
            start.fail(error)
        }
        #expect(stateMachine.state == .error)

        // Nothing more is sent, and the promise isn't handed out a second time.
        #expect(throws: InvalidClientState.self) {
            try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5))))
            )
        }
        #expect(stateMachine.channelInactive().isEmpty)
    }

    /// Unreachable today: `.finish` carries no literal. Injects the state to check that it fails closed
    /// rather than sending the rest of the part after the APPEND completed.
    @Test("APPEND completing while a part waits for + fails the part's write")
    func completionWhileWaitingForLiteral() {
        let eventLoop = EmbeddedEventLoop()
        var stateMachine = ClientStateMachine(encodingOptions: .fixed(.rfc3501))
        stateMachine.handlerAdded(ByteBufferAllocator())

        let start = eventLoop.makePromise(of: Void.self)
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .init("å"))), promise: start)
        }
        guard case .appendingLiteral(var append, let context) = stateMachine.state else {
            Issue.record("Should wait for +, not \(stateMachine.state)")
            start.succeed()
            return
        }
        append.state = .waitingForTaggedResponse
        stateMachine.state = .appendingLiteral(append, context)

        do {
            _ = try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "")))))
            Issue.record("Completing the APPEND mid-part must throw")
            start.succeed()
        } catch let error as UnexpectedResponse {
            #expect(error.kind == .appendWithPendingContinuation)
            #expect(error.activePromise?.futureResult === start.futureResult)
            start.fail(error)
        } catch {
            Issue.record("Unexpected error \(error)")
            start.fail(error)
        }
        #expect(stateMachine.state == .error)
        #expect(stateMachine.channelInactive().isEmpty)
    }
}

extension IMAPClientHandlerTests.Helper {
    /// All bytes written to the wire since the last call, concatenated.
    func drainOutbound(sourceLocation: SourceLocation = #_sourceLocation) -> String {
        var wire = ""
        while true {
            var next: ByteBuffer?
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                next = try self.channel.readOutbound(as: ByteBuffer.self)
            }
            guard let next else { return wire }
            wire += String(buffer: next)
        }
    }
}
