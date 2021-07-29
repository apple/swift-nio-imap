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
import XCTest

class ClientStateMachineTests: XCTestCase {
    var stateMachine: ClientStateMachine!

    override func setUp() {
        self.stateMachine = ClientStateMachine()
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

    func testCantAuthenticateWithAnotherCommand() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .authenticate(mechanism: .gssAPI, initialResponse: nil))))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    func testCantAppendWithAnotherCommand() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.append(.start(tag: "A2", appendingTo: .inbox)))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    func testCantIdleWithAnotherCommand() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart)))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
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
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.idleStarted))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.idleDone))

        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }

    func testIdleWorkflow_commandWhileIdle() {
        // set up the state machine to idle
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.idleStarted))

        // machine is idle, so sending a different command should throw
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    func testIdleWorkflow_commandBeforeIdleConfirmed() {
        // set up the state machine to idle
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))))

        // machine isn't yet idle, but we've started the process
        // so sending a different command should throw
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))) { e in
            XCTAssertTrue(e is InvalidIdleState)
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
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.authenticationChallenge("c1")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.continuationResponse("r1")))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.authenticationChallenge("c2")))
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

    func testAuthenticationWorkflow_commandWhileAuthenticating() {
        // set up the state machine to authenticate
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .authenticate(mechanism: .gssAPI, initialResponse: nil)))))

        // machine is authenticating, so sending a different command should throw
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
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
    func testAppendWorflow_normal() {
        // start the append command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.start(tag: "A1", appendingTo: .inbox))))

        // append a message
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("ready1")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("01234"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("56789"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.endMessage)))

        // catenate some urls and a message
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginCatenate(options: .init()))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateURL("url1"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateURL("url2"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10)))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("ready2")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("01234"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("56789"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.endCatenate)))

        // show that we can finish the append command, and then send another different command
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.finish)))
        XCTAssertNoThrow(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop))))
    }
}
