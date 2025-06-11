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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class ClientStateMachineTests: XCTestCase {
    var stateMachine: ClientStateMachine!

    override func setUp() {
        self.stateMachine = ClientStateMachine(encodingOptions: .fixed(.rfc3501))
        self.stateMachine.handlerAdded(ByteBufferAllocator())
    }

    func testNormalWorkflow() {
        // NOOP
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        )

        // LOGIN one continuation
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .tagged(.init(tag: "A3", command: .login(username: "å", password: "hey")))
            )
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .no(.init(text: "Invalid")))))
        )

        // LOGIN two continuations
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .tagged(.init(tag: "A3", command: .login(username: "å", password: "ß")))
            )
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .no(.init(text: "Invalid")))))
        )

        // IDLE
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.responseText(.init(text: "OK"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.idleDone))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "OK")))))
        )

        // SELECT
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A5", command: .select(.inbox, [])))))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A5", state: .ok(.init(text: "OK")))))
        )

        // APPEND
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.start(tag: "A4", appendingTo: .inbox))))
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
            )
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("0123456789"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.endMessage)))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.finish)))
    }

    // send a command that requires chunking
    // so make sure the action we get back from
    // the state machine is telling us to chunk
    func testChunking() {
        let command = TaggedCommand(tag: "A1", command: .login(username: "å", password: "ß"))

        // send the command, the state machine should tell us to send the first chunk
        var result: OutgoingChunk?
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result?.bytes, "A1 LOGIN {2}\r\n")

        // receive a continuation, we should then send another chunk
        var action: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(action = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(action, .sendChunks([.init(bytes: "å {2}\r\n", promise: nil, shouldSucceedPromise: false)]))

        // receive a continuation again
        XCTAssertNoThrow(action = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(action, .sendChunks([.init(bytes: "ß\r\n", promise: nil, shouldSucceedPromise: true)]))

        // this time we expect a tagged response, so let's send one
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        )
    }

    func testChunkingMultipleCommands() {
        let command = TaggedCommand(tag: "A1", command: .login(username: "å", password: "pass"))

        var result1: OutgoingChunk?
        XCTAssertNoThrow(result1 = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result1!.bytes, "A1 LOGIN {2}\r\n")

        // We haven't yet continued the first command
        // so we shouldn't get anything back here.
        var result2: OutgoingChunk?
        XCTAssertNoThrow(result2 = try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))))
        XCTAssertNil(result2)
        self.stateMachine.flush()

        var result3: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(result3 = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(
            result3,
            .sendChunks([
                .init(bytes: "å \"pass\"\r\n", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "A2 NOOP\r\n", promise: nil, shouldSucceedPromise: true),
            ])
        )
    }

    func testMultipleCommandsCanRunConcurrently() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A4", command: .noop))))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "OK")))))
        )
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A4", state: .ok(.init(text: "OK")))))
        )
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        )
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .ok(.init(text: "OK")))))
        )
    }

    func testDuplicateTagThrows() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop)))) { e in
            XCTAssertTrue(e is DuplicateCommandTag)
        }
    }

    func testReceivingUntaggedWhileExpectingLiteralContinuationRequest() {
        let command = TaggedCommand(tag: "A1", command: .select(MailboxName(ByteBuffer(string: "äÿ")), []))

        var result1: OutgoingChunk?
        XCTAssertNoThrow(result1 = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result1!.bytes, "A1 SELECT {4}\r\n")

        // At this point, we’re waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A1 SELECT {4}
        // S: * 3 EXPUNGE
        // S: + Ready for literal data
        // C: äÿ
        // ```

        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.untagged(.messageData(.expunge(3)))),
            "Should be ignored."
        )
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(
            resultAction = try self.stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        )
        XCTAssertEqual(
            resultAction,
            .sendChunks([
                .init(bytes: "äÿ\r\n", promise: nil, shouldSucceedPromise: true)
            ])
        )
    }

    func testReceivingTaggedWhileExpectingLiteralContinuationRequest() {
        var result: OutgoingChunk?

        // Send a command that we can complete later:
        XCTAssertNoThrow(
            result = try self.stateMachine.sendCommand(.tagged(.init(tag: "B2", command: .expunge)))
        )
        XCTAssertEqual(result!.bytes, "B2 EXPUNGE\r\n")

        // Now send a command that will drop us into “expecting literal Continuation Request”:
        let command = TaggedCommand(tag: "A1", command: .select(MailboxName(ByteBuffer(string: "äÿ")), []))
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result!.bytes, "A1 SELECT {4}\r\n")

        // At this point, we’re waiting for a Continuation Request from the server.
        // But we may end up getting a (tagged) command completion first:
        // ```
        // C: A1 SELECT {4}
        // S: B2 OK EXPUNGE completed
        // S: + Ready for literal data
        // C: äÿ
        // ```

        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(
                .tagged(.init(tag: "B2", state: .ok(.init(text: "EXPUNGE completed"))))
            ),
            "Should be ignored"
        )
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(
            resultAction = try self.stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        )
        XCTAssertEqual(
            resultAction,
            .sendChunks([
                .init(bytes: "äÿ\r\n", promise: nil, shouldSucceedPromise: true)
            ])
        )
    }

    func testReceivingTaggedForCurrentCommandWhileExpectingLiteralContinuationRequest() {
        var result: OutgoingChunk?

        // Send a command that will drop us into “expecting literal Continuation Request”:
        let command = TaggedCommand(tag: "A1", command: .select(MailboxName(ByteBuffer(string: "äÿ")), []))
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result!.bytes, "A1 SELECT {4}\r\n")

        // If we receive a (tagged) completion for the current command, we need to throw an error:
        // ```
        // C: A1 SELECT {4}
        // S: A1 OK Completed
        // ```

        XCTAssertThrowsError(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "Completed")))))
        )
    }
}

// MARK: - IDLE

extension ClientStateMachineTests {
    func testIdleWorkflow_normal() {
        // set up the state machine, show we can send a command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        )

        // 1. start idle
        // 2. server confirms idle
        // 3. end idle
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.idleDone))

        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }

    func testIdleWorkflow_multipleContinuationRequests() {
        // set up the state machine to idle
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started"))))

        // machine is idle, so sending a different command should throw
        XCTAssertThrowsError(
            try self.stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))
        ) { e in
            XCTAssertTrue(e is UnexpectedContinuationRequest)
        }
    }
}

// MARK: - Authentication

extension ClientStateMachineTests {
    func testAuthenticationWorkflow_normal() {
        // set up the state machine, show we can send a command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        )

        // 1. start authenticating
        // 2. a couple of challenges back and forth
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("c1")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.continuationResponse("r1")))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("c2")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.continuationResponse("r2")))

        // finish authenticating
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(code: nil, text: "OK")))))
        )

        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }

    func testAuthenticationWorkflow_normal_noChallenges() {
        // set up the state machine, show we can send a command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        )

        // 1. start authenticating
        // 2. server immediately confirms
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        )
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(code: nil, text: "OK")))))
        )

        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }

    func testAuthenticationWorkflow_untagged() {
        // set up the state machine to authenticate
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        )

        // machine is authenticating, so sending an untagged response should be ignored
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.untagged(.enableData([.metadata]))))
    }

    func testAuthenticationWorkflow_unexpectedResponse() {
        // set up the state machine to authenticate
        XCTAssertNoThrow(
            try self.stateMachine.sendCommand(
                .tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        )

        // machine is authenticating, so sending idle started should throw
        XCTAssertThrowsError(try self.stateMachine.receiveResponse(.idleStarted)) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }
}

// MARK: - Append

extension ClientStateMachineTests {
    func assert(
        _ expected: OutgoingChunk,
        _ closure: @autoclosure () throws -> OutgoingChunk?,
        line: UInt = #line
    ) {
        var result: OutgoingChunk?
        XCTAssertNoThrow(result = try closure(), line: line)

        XCTAssertTrue(expected.promise?.futureResult === result?.promise?.futureResult, line: line)
        XCTAssertEqual(expected.bytes, result?.bytes, line: line)
        XCTAssertEqual(expected.shouldSucceedPromise, result?.shouldSucceedPromise, line: line)
    }

    func testAppendWorkflow_normal() {
        // start the append command
        self.assert(
            .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))
        )

        // append a message
        self.assert(
            .init(bytes: " {10}\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
            )
        )
        XCTAssertNoThrow(
            XCTAssertEqual(
                try self.stateMachine.receiveContinuationRequest(.data("ready2")),
                .sendChunks([])
            )
        )
        self.assert(
            .init(bytes: "01234", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.messageBytes("01234")))
        )
        self.assert(
            .init(bytes: "56789", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.messageBytes("56789")))
        )
        self.assert(
            .init(bytes: "", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.endMessage))
        )

        // catenate some urls and a message
        self.assert(
            .init(bytes: " CATENATE (", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.beginCatenate(options: .init())))
        )
        self.assert(
            .init(bytes: "URL \"url1\"", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.catenateURL("url1")))
        )
        self.assert(
            .init(bytes: " URL \"url2\"", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.catenateURL("url2")))
        )
        self.assert(
            .init(bytes: " TEXT {10}\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10))))
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("ready2")))
        self.assert(
            .init(bytes: "01234", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.catenateData(.bytes("01234"))))
        )
        self.assert(
            .init(bytes: "56789", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.catenateData(.bytes("56789"))))
        )
        self.assert(
            .init(bytes: "", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.catenateData(.end)))
        )
        self.assert(
            .init(bytes: ")", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.endCatenate))
        )

        // show that we can finish the append command, and then send another different command
        self.assert(
            .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.finish))
        )
        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK")))))
        )
        self.assert(
            .init(bytes: "A2 NOOP\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))
        )
    }

    func testAppendWorkflow_receivingUntaggedResponses() throws {
        // start the append command
        self.assert(
            .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))
        )

        // append a message
        self.assert(
            .init(bytes: " {10}\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
            )
        )
        XCTAssertNoThrow(
            XCTAssertEqual(
                try self.stateMachine.receiveContinuationRequest(.data("ready2")),
                .sendChunks([])
            )
        )
        self.assert(
            .init(bytes: "0123456789", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.messageBytes("0123456789")))
        )
        self.assert(
            .init(bytes: "", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.endMessage))
        )

        // Send an untagged EXISTS:
        try self.stateMachine.receiveResponse(.untagged(.mailboxData(.exists(5_732))))

        // Finish the append command, and then send another different command
        self.assert(
            .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.append(.finish))
        )

        // Send an untagged RECENT:
        try self.stateMachine.receiveResponse(.untagged(.mailboxData(.recent(0))))

        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK")))))
        )
        self.assert(
            .init(bytes: "A2 NOOP\r\n", promise: nil, shouldSucceedPromise: true),
            try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))
        )
    }

    func testAppendPreloading() {
        var result: OutgoingChunk?
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox))))
        XCTAssertEqual(result, .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(
            result = try self.stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5))))
            )
        )
        XCTAssertEqual(result, .init(bytes: " {5}\r\n", promise: nil, shouldSucceedPromise: true))

        // We’ll now enqueue a lot of CommandStreamPart that can’t be sent onto the wire, yet,
        // because we’re still waiting for the Continuation Request from the server:
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("0"))))
        XCTAssertNil(result)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("1"))))
        XCTAssertNil(result)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("2"))))
        XCTAssertNil(result)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("3"))))
        XCTAssertNil(result)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("4"))))
        XCTAssertNil(result)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.endMessage)))
        XCTAssertNil(result)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.finish)))
        XCTAssertNil(result)
        self.stateMachine.flush()

        // Now the Continuation Request comes in:
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(resultAction = try self.stateMachine.receiveContinuationRequest(.data("OK")))

        // We should send the pending chunks at this point:
        XCTAssertEqual(
            resultAction,
            .sendChunks([
                .init(bytes: "0", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "1", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "2", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "3", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "4", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "", promise: nil, shouldSucceedPromise: true),
                .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true),
            ])
        )

        // Complete the APPEND command:
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: ""))))))

        guard
            case .expectingNormalResponse = self.stateMachine.state
        else {
            XCTFail("\(self.stateMachine.state)")
            return
        }
    }

    func testAppendReceivingUntaggedWhileWaitingForContinuationRequest() {
        var result: OutgoingChunk?
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox))))
        XCTAssertEqual(result, .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(
            result = try self.stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 6))))
            )
        )
        XCTAssertEqual(result, .init(bytes: " {6}\r\n", promise: nil, shouldSucceedPromise: true))

        // At this point, we’re waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A003 APPEND saved-messages (\Seen) {5}
        // S: * 3 EXPUNGE
        // S: + Ready for literal data
        // C: foobar
        // ```

        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.untagged(.messageData(.expunge(3)))),
            "Should be ignored."
        )
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(
            resultAction = try self.stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        )
        XCTAssertEqual(resultAction, .sendChunks([]))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("foobar"))))
        XCTAssertEqual(result, .init(bytes: "foobar", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.endMessage)))
        XCTAssertEqual(result, .init(bytes: "", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.finish)))
        XCTAssertEqual(result, .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true))

        // Complete the APPEND command:
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: ""))))))

        guard
            case .expectingNormalResponse = self.stateMachine.state
        else {
            XCTFail("\(self.stateMachine.state)")
            return
        }
    }

    func testAppendReceivingTtaggedWhileWaitingForContinuationRequest() {
        var result: OutgoingChunk?

        // Send a command that we can complete later:
        XCTAssertNoThrow(
            result = try self.stateMachine.sendCommand(.tagged(.init(tag: "B2", command: .expunge)))
        )
        XCTAssertEqual(result!.bytes, "B2 EXPUNGE\r\n")

        // Now send the APPEND:
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox))))
        XCTAssertEqual(result, .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(
            result = try self.stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 6))))
            )
        )
        XCTAssertEqual(result, .init(bytes: " {6}\r\n", promise: nil, shouldSucceedPromise: true))

        // At this point, we’re waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A003 APPEND saved-messages (\Seen) {5}
        // S: B2 OK EXPUNGE completed
        // S: + Ready for literal data
        // C: foobar
        // ```

        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(
                .tagged(.init(tag: "B2", state: .ok(.init(text: "EXPUNGE completed"))))
            ),
            "Should be ignored"
        )
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(
            resultAction = try self.stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        )
        XCTAssertEqual(resultAction, .sendChunks([]))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("foobar"))))
        XCTAssertEqual(result, .init(bytes: "foobar", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.endMessage)))
        XCTAssertEqual(result, .init(bytes: "", promise: nil, shouldSucceedPromise: true))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.finish)))
        XCTAssertEqual(result, .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true))

        // Complete the APPEND command:
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: ""))))))

        guard
            case .expectingNormalResponse = self.stateMachine.state
        else {
            XCTFail("\(self.stateMachine.state)")
            return
        }
    }

    func testSendingAnAuthenticationChallengeWhenUnexpectedThrows() {
        XCTAssertThrowsError(try self.stateMachine.receiveResponse(.authenticationChallenge("challenge"))) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }

    func testSendingIdleStartedWhenUnexpectedThrows() {
        XCTAssertThrowsError(try self.stateMachine.receiveResponse(.idleStarted)) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }
}
