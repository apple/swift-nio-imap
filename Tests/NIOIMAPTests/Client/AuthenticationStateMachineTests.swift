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
        XCTAssertNoThrow(try stateMachine.receiveContinuationRequest(.data("challenge1")))
        stateMachine.sendCommand(.continuationResponse("response1"))
        XCTAssertNoThrow(try stateMachine.receiveContinuationRequest(.data("challenge2")))
        stateMachine.sendCommand(.continuationResponse("response2"))
        XCTAssertNoThrow(try stateMachine.receiveContinuationRequest(.data("challenge3")))
        stateMachine.sendCommand(.continuationResponse("response3"))
        XCTAssertEqual(stateMachine.state, .waitingForServer)

        // finish
        XCTAssertNoThrow(try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))))
        XCTAssertEqual(stateMachine.state, .finished)
    }

    func testReceivingUntaggedDuringAuthentication() {
        var stateMachine = ClientStateMachine.Authentication()

        // send and respond to a couple of challenges
        XCTAssertNoThrow(try stateMachine.receiveContinuationRequest(.data("challenge1")))
        stateMachine.sendCommand(.continuationResponse("response1"))
        XCTAssertNoThrow(try stateMachine.receiveResponse(.untagged(.capabilityData([.imap4rev1]))))
        XCTAssertEqual(stateMachine.state, .waitingForServer)

        // finish
        XCTAssertNoThrow(try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))))
        XCTAssertEqual(stateMachine.state, .finished)
    }

    func testDuplicateChallengeThrows() {
        var stateMachine = ClientStateMachine.Authentication()
        XCTAssertNoThrow(try stateMachine.receiveContinuationRequest(.data("c1")))

        XCTAssertThrowsError(try stateMachine.receiveResponse(.authenticationChallenge("c2"))) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }
}
