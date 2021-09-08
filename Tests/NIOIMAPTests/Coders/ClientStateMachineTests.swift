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
        self.stateMachine = ClientStateMachine(encodingOptions: .rfc3501)
        self.stateMachine.allocator = ByteBufferAllocator()
    }

    func testNormalWorkflow() {
        // NOOP
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK"))))))

        // LOGIN
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .login(username: "\\", password: "\\")))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .no(.init(text: "Invalid"))))))

        // IDLE
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.responseText(.init(text: "OK"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.idleDone))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "OK"))))))

        // SELECT
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A5", command: .select(.inbox, [])))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A5", state: .ok(.init(text: "OK"))))))

        // APPEND
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.start(tag: "A4", appendingTo: .inbox))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("0123456789"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.endMessage)))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.finish)))
    }

    // send a command that requires chunking
    // so make sure the action we get back from
    // the state machine is telling us to chunk
    func testChunking() {
        let command = TaggedCommand(tag: "A1", command: .login(username: "\\", password: "\\"))

        // send the command, the state machine should tell us to send the first chunk
        var result: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] = []
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.0.bytes, "A1 LOGIN {1}\r\n")

        // receive a continuation, we should then send another chunk
        var action: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(action = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(action, .sendChunks([(.init(bytes: "\\ {1}\r\n", waitForContinuation: true), nil)]))

        // receive a continuation again
        XCTAssertNoThrow(action = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(action, .sendChunks([(.init(bytes: "\\\r\n", waitForContinuation: false), nil)]))

        // this time we expect a tagged response, so let's send one
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK"))))))
    }

    func testChunkingMultipleCommands() {
        let command = TaggedCommand(tag: "A1", command: .login(username: "\\", password: "pass"))

        var result1: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] = []
        XCTAssertNoThrow(result1 = try self.stateMachine.sendCommand(.tagged(command)))
        XCTAssertEqual(result1.count, 1)
        XCTAssertEqual(result1.first!.0.bytes, "A1 LOGIN {1}\r\n")

        // We haven't yet continued the first command
        // so we shouldn't get anything back here.
        var result2: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] = []
        XCTAssertNoThrow(result2 = try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))))
        XCTAssertEqual(result2.count, 0)
        self.stateMachine.flush()

        var result3: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(result3 = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(result3, .sendChunks([
            (.init(bytes: "\\ \"pass\"\r\n", waitForContinuation: false), nil),
            (.init(bytes: "A2 NOOP\r\n", waitForContinuation: false), nil),
        ]))
    }

    func testMultipleCommandsCanRunConcurrently() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A4", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "OK"))))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A4", state: .ok(.init(text: "OK"))))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK"))))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .ok(.init(text: "OK"))))))
    }

    func testDuplicateTagThrows() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop)))) { e in
            XCTAssertTrue(e is DuplicateCommandTag)
        }
    }
}

// MARK: - IDLE

extension ClientStateMachineTests {
    func testIdleWorkflow_normal() {
        // set up the state machine, show we can send a command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK"))))))

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
        XCTAssertThrowsError(try self.stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))) { e in
            XCTAssertTrue(e is UnexpectedContinuationRequest)
        }
    }
}

// MARK: - Authentication

extension ClientStateMachineTests {
    func testAuthenticationWorkflow_normal() {
        // set up the state machine, show we can send a command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK"))))))

        // 1. start authenticating
        // 2. a couple of challenges back and forth
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("c1")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.continuationResponse("r1")))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("c2")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.continuationResponse("r2")))

        // finish authenticating
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(code: nil, text: "OK"))))))

        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }

    func testAuthenticationWorkflow_normal_noChallenges() {
        // set up the state machine, show we can send a command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK"))))))

        // 1. start authenticating
        // 2. server immediately confirms
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(code: nil, text: "OK"))))))

        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }

    func testAuthenticationWorkflow_unexpectedResponse() {
        // set up the state machine to authenticate
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))))

        // machine is authenticating, so sending an untagged response should throw
        XCTAssertThrowsError(try self.stateMachine.receiveResponse(.untagged(.enableData([.metadata])))) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }
}

// MARK: - Append

extension ClientStateMachineTests {
    func assert(
        _ expected: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)],
        _ closure: @autoclosure () throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)],
        line: UInt = #line
    ) {
        var result: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] = []
        XCTAssertNoThrow(result = try closure(), line: line)

        // used this instead of elementsEqual because it works better with
        // XCTAssert
        for (lhs, rhs) in zip(expected, result) {
            XCTAssertTrue(lhs.1?.futureResult === rhs.1?.futureResult, line: line)
            XCTAssertEqual(lhs.0, rhs.0, line: line)
        }
    }

    func testAppendWorflow_normal() {
        // start the append command
        self.assert(
            [(.init(bytes: "A1 APPEND \"INBOX\"", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))
        )

        // append a message
        self.assert(
            [(.init(bytes: " {10}\r\n", waitForContinuation: true), nil)],
            try self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10)))))
        )
        XCTAssertNoThrow(XCTAssertEqual(
            try self.stateMachine.receiveContinuationRequest(.data("ready2")),
            .sendChunks([(.init(bytes: ByteBuffer(), waitForContinuation: false), nil)])
        ))
        self.assert(
            [(.init(bytes: "01234", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.messageBytes("01234")))
        )
        self.assert(
            [(.init(bytes: "56789", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.messageBytes("56789")))
        )
        self.assert(
            [(.init(bytes: "", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.endMessage))
        )

        // catenate some urls and a message
        self.assert(
            [(.init(bytes: " CATENATE (", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.beginCatenate(options: .init())))
        )
        self.assert(
            [(.init(bytes: "URL \"url1\"", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.catenateURL("url1")))
        )
        self.assert(
            [(.init(bytes: " URL \"url2\"", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.catenateURL("url2")))
        )
        self.assert(
            [(.init(bytes: " TEXT {10}\r\n", waitForContinuation: true), nil)],
            try self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10))))
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("ready2")))
        self.assert(
            [(.init(bytes: "01234", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.catenateData(.bytes("01234"))))
        )
        self.assert(
            [(.init(bytes: "56789", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.catenateData(.bytes("56789"))))
        )
        self.assert(
            [(.init(bytes: "", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.catenateData(.end)))
        )
        self.assert(
            [(.init(bytes: ")", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.endCatenate))
        )

        // show that we can finish the append command, and then send another different command
        self.assert(
            [(.init(bytes: "\r\n", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.append(.finish))
        )
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))))
        self.assert(
            [(.init(bytes: "A2 NOOP\r\n", waitForContinuation: false), nil)],
            try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))
        )
    }

    func testAppeandPreloading() {
        var result: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] = []
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox))))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].0, .init(bytes: "A1 APPEND \"INBOX\"", waitForContinuation: false))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5))))))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].0, .init(bytes: " {5}\r\n", waitForContinuation: true))

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("0"))))
        XCTAssertEqual(result.count, 0)
        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("1"))))
        XCTAssertEqual(result.count, 0)

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("2"))))
        XCTAssertEqual(result.count, 0)

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("3"))))
        XCTAssertEqual(result.count, 0)

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.messageBytes("4"))))
        XCTAssertEqual(result.count, 0)

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.endMessage)))
        XCTAssertEqual(result.count, 0)

        XCTAssertNoThrow(result = try self.stateMachine.sendCommand(.append(.finish)))
        XCTAssertEqual(result.count, 0)

        self.stateMachine.flush()

        var resultAction: ClientStateMachine.ContinuationRequestAction!
        XCTAssertNoThrow(resultAction = try self.stateMachine.receiveContinuationRequest(.data("OK")))
        XCTAssertEqual(resultAction, .sendChunks([
            (.init(bytes: "", waitForContinuation: false), nil),
            (.init(bytes: "0", waitForContinuation: false), nil),
            (.init(bytes: "1", waitForContinuation: false), nil),
            (.init(bytes: "2", waitForContinuation: false), nil),
            (.init(bytes: "3", waitForContinuation: false), nil),
            (.init(bytes: "4", waitForContinuation: false), nil),
            (.init(bytes: "", waitForContinuation: false), nil),
            (.init(bytes: "\r\n", waitForContinuation: false), nil),
        ]))
    }

    func testSendingAnAuthencationChallengeWhenUnexpectedThrows() {
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
