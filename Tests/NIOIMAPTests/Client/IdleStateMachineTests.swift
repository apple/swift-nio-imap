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

@Suite struct IdleStateMachineTests {
    @Test("normal workflow untagged")
    func normalWorkflowUntagged() {
        var machine = ClientStateMachine.Idle()

        // server confirms idle
        #expect(throws: Never.self) { try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }

        // server is allowed to send untagged responses while idle
        #expect(throws: Never.self) { try machine.receiveResponse(.untagged(.id(["Key1": "Value1"]))) }
        #expect(throws: Never.self) { try machine.receiveResponse(.untagged(.id(["Key2": "Value2"]))) }
        #expect(throws: Never.self) { try machine.receiveResponse(.untagged(.id(["Key3": "Value3"]))) }

        // user ends idle
        machine.sendCommand(.idleDone)
    }

    @Test("normal workflow fetch")
    func normalWorkflowFetch() {
        var machine = ClientStateMachine.Idle()

        // server confirms idle
        #expect(throws: Never.self) { try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }

        // server is allowed to send untagged responses while idle.
        // `Response.fetch` are all untagged responses.
        #expect(throws: Never.self) { try machine.receiveResponse(.fetch(.start(1))) }
        #expect(throws: Never.self) { try machine.receiveResponse(.fetch(.simpleAttribute(.flags([.answered])))) }
        #expect(throws: Never.self) { try machine.receiveResponse(.fetch(.simpleAttribute(.uid(999)))) }
        #expect(throws: Never.self) { try machine.receiveResponse(.fetch(.finish)) }

        // user ends idle
        machine.sendCommand(.idleDone)
    }

    @Test("multiple idle confirmations throws error")
    func multipleIdleConfirmationsThrowsError() {
        var machine = ClientStateMachine.Idle()
        #expect(throws: Never.self) { try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }

        // server cannot confirm idle twice
        #expect(throws: UnexpectedContinuationRequest.self) {
            try machine.receiveContinuationRequest(.responseText(.init(text: "OK")))
        }
    }

    @Test("incorrect response type throws error")
    func incorrectResponseTypeThrowsError() {
        var machine = ClientStateMachine.Idle()

        // expecting a continuation to confirm idle has started
        // but instead let's send a tagged response
        let badResponse = Response.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "ok"))))
        #expect(throws: UnexpectedResponse.self) {
            try machine.receiveResponse(badResponse)
        }
    }

    @Test("send response after finished throws")
    func sendResponseAfterFinishedThrows() {
        var machine = ClientStateMachine.Idle()
        #expect(throws: Never.self) { try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }
        machine.sendCommand(.idleDone)

        let badResponse = Response.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "ok"))))
        #expect(throws: UnexpectedResponse.self) {
            try machine.receiveResponse(badResponse)
        }
    }
}
