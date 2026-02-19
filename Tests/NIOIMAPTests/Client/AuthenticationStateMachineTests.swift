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
import Testing

@Suite struct AuthenticationStateMachineTests {
    @Test func `normal workflow`() {
        var stateMachine = ClientStateMachine.Authentication()

        // send and respond to a couple of challenges
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("challenge1")) }
        stateMachine.sendCommand(.continuationResponse("response1"))
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("challenge2")) }
        stateMachine.sendCommand(.continuationResponse("response2"))
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("challenge3")) }
        stateMachine.sendCommand(.continuationResponse("response3"))
        #expect(stateMachine.state == .waitingForServer)

        // finish
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK")))))
        }
        #expect(stateMachine.state == .finished)
    }

    @Test func `receiving untagged during authentication`() {
        var stateMachine = ClientStateMachine.Authentication()

        // send and respond to a couple of challenges
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("challenge1")) }
        stateMachine.sendCommand(.continuationResponse("response1"))
        #expect(throws: Never.self) { try stateMachine.receiveResponse(.untagged(.capabilityData([.imap4rev1]))) }
        #expect(stateMachine.state == .waitingForServer)

        // finish
        #expect(throws: Never.self) {
            try stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK")))))
        }
        #expect(stateMachine.state == .finished)
    }

    @Test func `duplicate challenge throws`() {
        var stateMachine = ClientStateMachine.Authentication()
        #expect(throws: Never.self) { try stateMachine.receiveContinuationRequest(.data("c1")) }

        #expect(throws: UnexpectedResponse.self) {
            try stateMachine.receiveResponse(.authenticationChallenge("c2"))
        }
    }
}
