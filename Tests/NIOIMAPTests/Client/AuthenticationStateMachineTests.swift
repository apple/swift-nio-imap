//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
@testable import NIOIMAP
import XCTest

class AuthenticationStateMachineTests: XCTestCase {
    func testNormalWorkflow() {
        var stateMachine = ClientStateMachine.Authentication()

        // send and respond to a couple of challenges
        XCTAssertNoThrow(try stateMachine.receiveResponse(.authenticationChallenge("challenge1")))
        XCTAssertNoThrow(try stateMachine.sendCommand(.continuationResponse("response1")))
        XCTAssertNoThrow(try stateMachine.receiveResponse(.authenticationChallenge("challenge2")))
        XCTAssertNoThrow(try stateMachine.sendCommand(.continuationResponse("response2")))
        XCTAssertNoThrow(try stateMachine.receiveResponse(.authenticationChallenge("challenge3")))
        XCTAssertNoThrow(try stateMachine.sendCommand(.continuationResponse("response3")))

        // finish
        XCTAssertNoThrow(try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))))
    }

    // no other command can be sent while we're authenticating
    func testSendingCommandWhileAuthenticatingShouldThrow() {
        var stateMachine = ClientStateMachine.Authentication()
        XCTAssertThrowsError(try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop)))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    // once the state machine has finished, it should be discarded
    func testInteractionAfterFinishThrowsError() {
        var stateMachine = ClientStateMachine.Authentication()
        XCTAssertNoThrow(try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))))

        // trying to send a challenge response should fail
        XCTAssertThrowsError(try stateMachine.sendCommand(.continuationResponse("test"))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }

        // receiving a challenge should fail
        XCTAssertThrowsError(try stateMachine.receiveResponse(.authenticationChallenge("test"))) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }

        // double finish should fail
        XCTAssertThrowsError(try stateMachine.receiveResponse(.authenticationChallenge("test"))) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }

    func testDuplicateChallengeThrows() {
        var stateMachine = ClientStateMachine.Authentication()
        XCTAssertNoThrow(try stateMachine.receiveResponse(.authenticationChallenge("c1")))

        XCTAssertThrowsError(try stateMachine.receiveResponse(.authenticationChallenge("c2"))) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }

    func testDuplicateChallengeResponseThrows() {
        var stateMachine = ClientStateMachine.Authentication()
        XCTAssertNoThrow(try stateMachine.receiveResponse(.authenticationChallenge("c1")))
        XCTAssertNoThrow(try stateMachine.sendCommand(.continuationResponse("r1")))

        XCTAssertThrowsError(try stateMachine.sendCommand(.continuationResponse("r2"))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    func testResponseWithoutChallengeThrows() {
        var stateMachine = ClientStateMachine.Authentication()
        XCTAssertThrowsError(try stateMachine.sendCommand(.continuationResponse("r2"))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }
}
