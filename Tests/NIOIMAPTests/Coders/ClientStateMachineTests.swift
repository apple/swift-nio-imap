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
import Testing

private func makeStateMachine() -> ClientStateMachine {
    var stateMachine = ClientStateMachine(encodingOptions: .fixed(.rfc3501))
    stateMachine.handlerAdded(ByteBufferAllocator())
    return stateMachine
}

struct ClientStateMachineTests {
    @Test("normal workflow")
    func normalWorkflow() {
        var stateMachine = makeStateMachine()
        // NOOP
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        }

        // LOGIN one continuation
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .tagged(.init(tag: "A3", command: .login(username: "å", password: "hey")))
            )
        }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .no(.init(text: "Invalid")))))
        }

        // LOGIN two continuations
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .tagged(.init(tag: "A3", command: .login(username: "å", password: "ß")))
            )
        }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .no(.init(text: "Invalid")))))
        }

        // IDLE
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart))) }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.idleDone) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "OK")))))
        }

        // SELECT
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(.tagged(.init(tag: "A5", command: .select(.inbox, []))))
        }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A5", state: .ok(.init(text: "OK")))))
        }

        // APPEND
        #expect(throws: Never.self) { try stateMachine.sendCommand(.append(.start(tag: "A4", appendingTo: .inbox))) }
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
            )
        }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.append(.messageBytes("0123456789"))) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.append(.endMessage)) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.append(.finish)) }
    }

    // send a command that requires chunking
    // so make sure the action we get back from
    // the state machine is telling us to chunk
    @Test("chunking")
    func chunking() {
        var stateMachine = makeStateMachine()
        let command = TaggedCommand(tag: "A1", command: .login(username: "å", password: "ß"))

        // send the command, the state machine should tell us to send the first chunk
        var result: OutgoingChunk?
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.tagged(command))?.chunk }
        #expect(result?.bytes == "A1 LOGIN {2}\r\n")

        // receive a continuation, we should then send another chunk
        var action: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) { action = try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(action == .sendChunks([.init(bytes: "å {2}\r\n", promise: nil, shouldSucceedPromise: false)]))

        // receive a continuation again
        #expect(throws: Never.self) { action = try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(action == .sendChunks([.init(bytes: "ß\r\n", promise: nil, shouldSucceedPromise: true)]))

        // this time we expect a tagged response, so let's send one
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        }
    }

    @Test("chunking multiple commands")
    func chunkingMultipleCommands() throws {
        var stateMachine = makeStateMachine()
        let command = TaggedCommand(tag: "A1", command: .login(username: "å", password: "pass"))

        var result1: OutgoingChunk?
        #expect(throws: Never.self) { result1 = try stateMachine.sendCommand(.tagged(command))?.chunk }
        #expect(result1!.bytes == "A1 LOGIN {2}\r\n")

        // We haven't yet continued the first command
        // so we shouldn't get anything back here.
        var result2: OutgoingChunk?
        #expect(throws: Never.self) {
            result2 = try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))?.chunk
        }
        #expect(result2 == nil)
        #expect(try stateMachine.flush() == [])

        var result3: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) { result3 = try stateMachine.receiveContinuationRequest(.data("OK")) }
        #expect(
            result3
                == .sendChunks([
                    .init(bytes: "å \"pass\"\r\n", promise: nil, shouldSucceedPromise: true),
                    .init(bytes: "A2 NOOP\r\n", promise: nil, shouldSucceedPromise: true),
                ])
        )
    }

    @Test("multiple commands can run concurrently")
    func multipleCommandsCanRunConcurrently() {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A4", command: .noop))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "OK")))))
        }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A4", state: .ok(.init(text: "OK")))))
        }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A3", state: .ok(.init(text: "OK")))))
        }
    }

    @Test("duplicate tag throws")
    func duplicateTagThrows() {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))) }
        #expect(throws: DuplicateCommandTag.self) {
            try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop)))
        }
    }

    @Test("receiving untagged while expecting literal continuation request")
    func receivingUntaggedWhileExpectingLiteralContinuationRequest() {
        var stateMachine = makeStateMachine()
        let command = TaggedCommand(tag: "A1", command: .select(MailboxName(ByteBuffer(string: "äÿ")), []))

        var result1: OutgoingChunk?
        #expect(throws: Never.self) { result1 = try stateMachine.sendCommand(.tagged(command))?.chunk }
        #expect(result1!.bytes == "A1 SELECT {4}\r\n")

        // At this point, we're waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A1 SELECT {4}
        // S: * 3 EXPUNGE
        // S: + Ready for literal data
        // C: äÿ
        // ```

        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.untagged(.messageData(.expunge(3))))
        }
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) {
            resultAction = try stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        }
        #expect(
            resultAction
                == .sendChunks([
                    .init(bytes: "äÿ\r\n", promise: nil, shouldSucceedPromise: true)
                ])
        )
    }

    @Test("receiving tagged while expecting literal continuation request")
    func receivingTaggedWhileExpectingLiteralContinuationRequest() {
        var stateMachine = makeStateMachine()
        var result: OutgoingChunk?

        // Send a command that we can complete later:
        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(.tagged(.init(tag: "B2", command: .expunge)))?.chunk
        }
        #expect(result!.bytes == "B2 EXPUNGE\r\n")

        // Now send a command that will drop us into "expecting literal Continuation Request":
        let command = TaggedCommand(tag: "A1", command: .select(MailboxName(ByteBuffer(string: "äÿ")), []))
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.tagged(command))?.chunk }
        #expect(result!.bytes == "A1 SELECT {4}\r\n")

        // At this point, we're waiting for a Continuation Request from the server.
        // But we may end up getting a (tagged) command completion first:
        // ```
        // C: A1 SELECT {4}
        // S: B2 OK EXPUNGE completed
        // S: + Ready for literal data
        // C: äÿ
        // ```

        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(
                .tagged(.init(tag: "B2", state: .ok(.init(text: "EXPUNGE completed"))))
            )
        }
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) {
            resultAction = try stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        }
        #expect(
            resultAction
                == .sendChunks([
                    .init(bytes: "äÿ\r\n", promise: nil, shouldSucceedPromise: true)
                ])
        )
    }

    @Test("receiving tagged for current command while expecting literal continuation request")
    func receivingTaggedForCurrentCommandWhileExpectingLiteralContinuationRequest() {
        var stateMachine = makeStateMachine()
        var result: OutgoingChunk?

        // Send a command that will drop us into "expecting literal Continuation Request":
        let command = TaggedCommand(tag: "A1", command: .select(MailboxName(ByteBuffer(string: "äÿ")), []))
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.tagged(command))?.chunk }
        #expect(result!.bytes == "A1 SELECT {4}\r\n")

        // If we receive a (tagged) completion for the current command, we need to throw an error:
        // ```
        // C: A1 SELECT {4}
        // S: A1 OK Completed
        // ```

        #expect(throws: (any Error).self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "Completed")))))
        }
    }
}

// MARK: - IDLE

extension ClientStateMachineTests {
    @Test("idle workflow normal")
    func idleWorkflowNormal() {
        var stateMachine = makeStateMachine()
        // set up the state machine, show we can send a command
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        }

        // 1. start idle
        // 2. server confirms idle
        // 3. end idle
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))
        }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.idleDone) }

        // state machine should have reset, so we can send a normal command again
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))) }
    }

    @Test("a tagged response after the IDLE confirmation is an error")
    func taggedResponseWhileIdlingIsAnError() {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "idling")))
        }

        // After its `+`, the server must wait for DONE (RFC 2177 §3).
        #expect(throws: UnexpectedResponse.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "IDLE terminated")))))
        }
        #expect(stateMachine.state == .error)
    }

    @Test("a fatal response during IDLE is an error")
    func fatalWhileIdlingIsAnError() {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "idling")))
        }

        #expect(throws: UnexpectedResponse.self) { try stateMachine.receiveResponse(.fatal(.init(text: "Autologout"))) }
        #expect(stateMachine.state == .error)
    }

    @Test(
        "a rejected IDLE absorbs one DONE",
        arguments: [
            TaggedResponse.State.no(.init(text: "IDLE not permitted")),
            .bad(.init(text: "IDLE not permitted")),
        ]
    )
    func rejectedIdleAbsorbsOneDone(rejection: TaggedResponse.State) throws {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }

        #expect(try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: rejection))) == [])
        #expect(stateMachine.state == .idleRejected)

        // The server never sent `+`, so it isn't waiting for DONE: nothing to write.
        let loop = EmbeddedEventLoop()
        let done = loop.makePromise(of: Void.self)
        #expect(try stateMachine.sendCommand(.idleDone, promise: done) == .succeed(done))
        #expect(stateMachine.state == .expectingNormalResponse)
        done.succeed()

        #expect(throws: InvalidCommandForState.self) { try stateMachine.sendCommand(.idleDone) }
    }

    @Test(
        "a command after a rejected IDLE ends the tolerance for a late DONE",
        arguments: [
            CommandStreamPart.tagged(.init(tag: "A2", command: .noop)),
            .append(.start(tag: "A2", appendingTo: .inbox)),
        ]
    )
    func commandAfterRejectedIdleEndsDoneTolerance(command: CommandStreamPart) throws {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        _ = try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .no(.init(text: "IDLE not permitted")))))
        #expect(stateMachine.state == .idleRejected)

        #expect(try stateMachine.sendCommand(command)?.chunk != nil)
        #expect(stateMachine.state != .idleRejected)
    }

    @Test("a continuation request after a rejected IDLE is an error")
    func continuationAfterRejectedIdleIsAnError() throws {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        _ = try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .no(.init(text: "IDLE not permitted")))))

        #expect(throws: UnexpectedContinuationRequest.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "idling")))
        }
        #expect(stateMachine.state == .error)
    }

    @Test("DONE sent before the IDLE confirmation is held until it arrives")
    func doneBeforeConfirmationIsHeld() throws {
        var stateMachine = makeStateMachine()
        let loop = EmbeddedEventLoop()
        let done = loop.makePromise(of: Void.self)
        let noop = loop.makePromise(of: Void.self)
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }

        // DONE answers the server's `+`, so it — and anything behind it — has to wait.
        #expect(try stateMachine.sendCommand(.idleDone, promise: done) == nil)
        #expect(try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)), promise: noop) == nil)
        #expect(try stateMachine.flush() == [])

        #expect(
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "idling")))
                == .fireIdleStarted([
                    .init(bytes: "DONE\r\n", promise: done, shouldSucceedPromise: true),
                    .init(bytes: "A2 NOOP\r\n", promise: noop, shouldSucceedPromise: true),
                ])
        )
        #expect(stateMachine.state == .expectingNormalResponse)
        done.succeed()
        noop.succeed()

        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "IDLE terminated")))))
        }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(text: "NOOP completed")))))
        }
    }

    @Test("DONE held for an IDLE that is then rejected is dropped")
    func heldDoneForRejectedIdleIsDropped() throws {
        var stateMachine = makeStateMachine()
        let loop = EmbeddedEventLoop()
        let done = loop.makePromise(of: Void.self)
        let noop = loop.makePromise(of: Void.self)
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        #expect(try stateMachine.sendCommand(.idleDone, promise: done) == nil)
        #expect(try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)), promise: noop) == nil)
        #expect(try stateMachine.flush() == [])

        // The held DONE is done with; the command behind it goes out.
        #expect(
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .no(.init(text: "IDLE not permitted")))))
                == [
                    .succeed(done),
                    .write(.init(bytes: "A2 NOOP\r\n", promise: noop, shouldSucceedPromise: true)),
                ]
        )
        #expect(stateMachine.state == .expectingNormalResponse)
        done.succeed()
        noop.succeed()

        // The held DONE was the one DONE a rejected IDLE absorbs.
        #expect(throws: InvalidCommandForState.self) { try stateMachine.sendCommand(.idleDone) }
    }

    @Test("a second DONE after a client-ended idle is still out of context")
    func secondDoneAfterClientEndedIdleThrows() {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))
        }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.idleDone) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "IDLE terminated")))))
        }

        // Only a rejected IDLE absorbs a DONE.
        #expect(throws: InvalidCommandForState.self) { try stateMachine.sendCommand(.idleDone) }
    }

    @Test("idle workflow with notifications before the confirmation")
    func idleWorkflowUntaggedBeforeConfirmation() {
        var stateMachine = makeStateMachine()
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        #expect(throws: Never.self) { try stateMachine.receiveResponse(.untagged(.mailboxData(.exists(3)))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))
        }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.idleDone) }
        #expect(stateMachine.state == .expectingNormalResponse)
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "IDLE terminated")))))
        }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))) }
    }

    @Test("idle workflow multiple continuation requests")
    func idleWorkflowMultipleContinuationRequests() {
        var stateMachine = makeStateMachine()
        // set up the state machine to idle
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))
        }

        // machine is idle, so sending a different command should throw
        #expect(throws: UnexpectedContinuationRequest.self) {
            try stateMachine.receiveContinuationRequest(.responseText(.init(text: "IDLE started")))
        }
    }
}

// MARK: - Authentication

extension ClientStateMachineTests {
    @Test("authentication workflow normal")
    func authenticationWorkflowNormal() {
        var stateMachine = makeStateMachine()
        // set up the state machine, show we can send a command
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        }

        // 1. start authenticating
        // 2. a couple of challenges back and forth
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("c1")) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.continuationResponse("r1")) }
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("c2")) }
        #expect(throws: Never.self) { try stateMachine.sendCommand(.continuationResponse("r2")) }

        // finish authenticating
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(code: nil, text: "OK")))))
        }

        // state machine should have reset, so we can send a normal command again
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))) }
    }

    @Test("authentication workflow normal no challenges")
    func authenticationWorkflowNormalNoChallenges() {
        var stateMachine = makeStateMachine()
        // set up the state machine, show we can send a command
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))) }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "OK")))))
        }

        // 1. start authenticating
        // 2. server immediately confirms
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        }
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A2", state: .ok(.init(code: nil, text: "OK")))))
        }

        // state machine should have reset, so we can send a normal command again
        #expect(throws: Never.self) { try stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))) }
    }

    @Test("authentication workflow untagged")
    func authenticationWorkflowUntagged() {
        var stateMachine = makeStateMachine()
        // set up the state machine to authenticate
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        }

        // machine is authenticating, so sending an untagged response should be ignored
        #expect(throws: Never.self) { try stateMachine.receiveResponse(.untagged(.enableData([.metadata]))) }
    }

    @Test("authentication workflow unexpected response")
    func authenticationWorkflowUnexpectedResponse() {
        var stateMachine = makeStateMachine()
        // set up the state machine to authenticate
        #expect(throws: Never.self) {
            try stateMachine.sendCommand(
                .tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))
            )
        }

        // machine is authenticating, so sending idle started should throw
        #expect(throws: UnexpectedResponse.self) {
            try stateMachine.receiveResponse(.idleStarted)
        }
    }

    @Test("sending a continuation response while expecting a normal response throws instead of crashing")
    func sendingContinuationResponseWhileExpectingNormalResponseThrows() {
        // A spurious `.continuationResponse` (e.g. one forwarded after being misparsed from
        // untrusted bytes) must not crash the process. A fresh state machine is in
        // `.expectingNormalResponse`, where this command is invalid.
        var stateMachine = makeStateMachine()
        #expect(throws: InvalidCommandForState.self) {
            try stateMachine.sendCommand(.continuationResponse("spurious"))
        }
    }

    @Test("sending idleDone while expecting a normal response throws instead of crashing")
    func sendingIdleDoneWhileExpectingNormalResponseThrows() {
        // Likewise, an out-of-context `.idleDone` must throw rather than hit a precondition.
        var stateMachine = makeStateMachine()
        #expect(throws: InvalidCommandForState.self) {
            try stateMachine.sendCommand(.idleDone)
        }
    }
}

// MARK: - Append

private func expectOutgoingChunk(
    _ expected: OutgoingChunk,
    _ closure: @autoclosure () throws -> OutboundAction?,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    var result: OutgoingChunk?
    #expect(throws: Never.self) { result = try closure()?.chunk }

    #expect(expected.promise?.futureResult === result?.promise?.futureResult, sourceLocation: sourceLocation)
    #expect(expected.bytes == result?.bytes, sourceLocation: sourceLocation)
    #expect(expected.shouldSucceedPromise == result?.shouldSucceedPromise, sourceLocation: sourceLocation)
}

extension ClientStateMachineTests {
    @Test("append workflow normal")
    func appendWorkflowNormal() {
        var stateMachine = makeStateMachine()
        // start the append command
        expectOutgoingChunk(
            .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))
        )

        // append a message
        expectOutgoingChunk(
            .init(bytes: " {10}\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
            )
        )
        var action: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) {
            action = try stateMachine.receiveContinuationRequest(.data("ready2"))
        }
        #expect(action == .sendChunks([]))
        expectOutgoingChunk(
            .init(bytes: "01234", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.messageBytes("01234")))
        )
        expectOutgoingChunk(
            .init(bytes: "56789", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.messageBytes("56789")))
        )
        expectOutgoingChunk(
            .init(bytes: "", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.endMessage))
        )

        // catenate some urls and a message
        expectOutgoingChunk(
            .init(bytes: " CATENATE (", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.beginCatenate(options: .init())))
        )
        expectOutgoingChunk(
            .init(bytes: "URL \"url1\"", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.catenateURL("url1")))
        )
        expectOutgoingChunk(
            .init(bytes: " URL \"url2\"", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.catenateURL("url2")))
        )
        expectOutgoingChunk(
            .init(bytes: " TEXT {10}\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.catenateData(.begin(size: 10))))
        )
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("ready2")) }
        expectOutgoingChunk(
            .init(bytes: "01234", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.catenateData(.bytes("01234"))))
        )
        expectOutgoingChunk(
            .init(bytes: "56789", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.catenateData(.bytes("56789"))))
        )
        expectOutgoingChunk(
            .init(bytes: "", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.catenateData(.end)))
        )
        expectOutgoingChunk(
            .init(bytes: ")", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.endCatenate))
        )

        // show that we can finish the append command, and then send another different command
        expectOutgoingChunk(
            .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.finish))
        )
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK")))))
        }
        expectOutgoingChunk(
            .init(bytes: "A2 NOOP\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))
        )
    }

    @Test("append workflow receiving untagged responses")
    func appendWorkflowReceivingUntaggedResponses() throws {
        var stateMachine = makeStateMachine()
        // start the append command
        expectOutgoingChunk(
            .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))
        )

        // append a message
        expectOutgoingChunk(
            .init(bytes: " {10}\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
            )
        )
        var action: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) {
            action = try stateMachine.receiveContinuationRequest(.data("ready2"))
        }
        #expect(action == .sendChunks([]))
        expectOutgoingChunk(
            .init(bytes: "0123456789", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.messageBytes("0123456789")))
        )
        expectOutgoingChunk(
            .init(bytes: "", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.endMessage))
        )

        // Send an untagged EXISTS:
        _ = try stateMachine.receiveResponse(.untagged(.mailboxData(.exists(5_732))))

        // Finish the append command, and then send another different command
        expectOutgoingChunk(
            .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.append(.finish))
        )

        // Send an untagged RECENT:
        _ = try stateMachine.receiveResponse(.untagged(.mailboxData(.recent(0))))

        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK")))))
        }
        expectOutgoingChunk(
            .init(bytes: "A2 NOOP\r\n", promise: nil, shouldSucceedPromise: true),
            try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))
        )
    }

    @Test("append preloading")
    func appendPreloading() throws {
        var stateMachine = makeStateMachine()
        var result: OutgoingChunk?
        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))?.chunk
        }
        #expect(result == .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 5))))
            )?.chunk
        }
        #expect(result == .init(bytes: " {5}\r\n", promise: nil, shouldSucceedPromise: true))

        // We'll now enqueue a lot of CommandStreamPart that can't be sent onto the wire, yet,
        // because we're still waiting for the Continuation Request from the server:
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("0")))?.chunk }
        #expect(result == nil)
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("1")))?.chunk }
        #expect(result == nil)
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("2")))?.chunk }
        #expect(result == nil)
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("3")))?.chunk }
        #expect(result == nil)
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("4")))?.chunk }
        #expect(result == nil)
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.endMessage))?.chunk }
        #expect(result == nil)
        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.finish))?.chunk }
        #expect(result == nil)
        #expect(try stateMachine.flush() == [])

        // Now the Continuation Request comes in:
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) { resultAction = try stateMachine.receiveContinuationRequest(.data("OK")) }

        // We should send the pending chunks at this point:
        #expect(
            resultAction
                == .sendChunks([
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
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "")))))
        }

        guard
            case .expectingNormalResponse = stateMachine.state
        else {
            Issue.record("\(stateMachine.state)")
            return
        }
    }

    @Test("append receiving untagged while waiting for continuation request")
    func appendReceivingUntaggedWhileWaitingForContinuationRequest() {
        var stateMachine = makeStateMachine()
        var result: OutgoingChunk?
        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))?.chunk
        }
        #expect(result == .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 6))))
            )?.chunk
        }
        #expect(result == .init(bytes: " {6}\r\n", promise: nil, shouldSucceedPromise: true))

        // At this point, we're waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A003 APPEND saved-messages (\Seen) {5}
        // S: * 3 EXPUNGE
        // S: + Ready for literal data
        // C: foobar
        // ```

        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.untagged(.messageData(.expunge(3))))
        }
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) {
            resultAction = try stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        }
        #expect(resultAction == .sendChunks([]))

        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("foobar")))?.chunk }
        #expect(result == .init(bytes: "foobar", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.endMessage))?.chunk }
        #expect(result == .init(bytes: "", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.finish))?.chunk }
        #expect(result == .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true))

        // Complete the APPEND command:
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "")))))
        }

        guard
            case .expectingNormalResponse = stateMachine.state
        else {
            Issue.record("\(stateMachine.state)")
            return
        }
    }

    @Test("append receiving ttagged while waiting for continuation request")
    func appendReceivingTtaggedWhileWaitingForContinuationRequest() {
        var stateMachine = makeStateMachine()
        var result: OutgoingChunk?

        // Send a command that we can complete later:
        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(.tagged(.init(tag: "B2", command: .expunge)))?.chunk
        }
        #expect(result!.bytes == "B2 EXPUNGE\r\n")

        // Now send the APPEND:
        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox)))?.chunk
        }
        #expect(result == .init(bytes: "A1 APPEND \"INBOX\"", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) {
            result = try stateMachine.sendCommand(
                .append(.beginMessage(message: .init(options: .none, data: .init(byteCount: 6))))
            )?.chunk
        }
        #expect(result == .init(bytes: " {6}\r\n", promise: nil, shouldSucceedPromise: true))

        // At this point, we're waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A003 APPEND saved-messages (\Seen) {5}
        // S: B2 OK EXPUNGE completed
        // S: + Ready for literal data
        // C: foobar
        // ```

        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(
                .tagged(.init(tag: "B2", state: .ok(.init(text: "EXPUNGE completed"))))
            )
        }
        var resultAction: ClientStateMachine.ContinuationRequestAction!
        #expect(throws: Never.self) {
            resultAction = try stateMachine.receiveContinuationRequest(.data("Ready for literal data"))
        }
        #expect(resultAction == .sendChunks([]))

        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.messageBytes("foobar")))?.chunk }
        #expect(result == .init(bytes: "foobar", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.endMessage))?.chunk }
        #expect(result == .init(bytes: "", promise: nil, shouldSucceedPromise: true))

        #expect(throws: Never.self) { result = try stateMachine.sendCommand(.append(.finish))?.chunk }
        #expect(result == .init(bytes: "\r\n", promise: nil, shouldSucceedPromise: true))

        // Complete the APPEND command:
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(text: "")))))
        }

        guard
            case .expectingNormalResponse = stateMachine.state
        else {
            Issue.record("\(stateMachine.state)")
            return
        }
    }

    @Test("sending an authentication challenge when unexpected throws")
    func sendingAnAuthenticationChallengeWhenUnexpectedThrows() {
        var stateMachine = makeStateMachine()
        #expect(throws: UnexpectedResponse.self) {
            try stateMachine.receiveResponse(.authenticationChallenge("challenge"))
        }
    }

    @Test("sending idle started when unexpected throws")
    func sendingIdleStartedWhenUnexpectedThrows() {
        var stateMachine = makeStateMachine()
        #expect(throws: UnexpectedResponse.self) {
            try stateMachine.receiveResponse(.idleStarted)
        }
    }
}

// MARK: - InvalidCommandForState PII redaction

extension ClientStateMachineTests {
    @Test("InvalidCommandForState redacts continuation-response PII")
    func invalidCommandForStateRedactsContinuationResponsePII() {
        // A continuation response can carry credentials (e.g. a SASL exchange), so neither the
        // raw bytes nor a plain rendering of them may appear in the error's description.
        let error = InvalidCommandForState(.continuationResponse(ByteBuffer(string: "topsecretcredentials")))

        #expect("\(error)" == "InvalidCommandForState([28 bytes]\r\n)")
        #expect(String(reflecting: error) == "InvalidCommandForState([28 bytes]\r\n)")
    }

    @Test("InvalidCommandForState redacts LOGIN credentials")
    func invalidCommandForStateRedactsLoginCredentials() {
        // LOGIN carries a username and password; neither may leak via the description.
        let error = InvalidCommandForState(
            .tagged(.init(tag: "A1", command: .login(username: "alice", password: "hunter2hunter2")))
        )

        #expect("\(error)" == "InvalidCommandForState(A1 LOGIN \"∅\" \"∅\"\r\n)")
    }
}
