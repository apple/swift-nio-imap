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
import NIO
@testable import NIOIMAP
import OrderedCollections
import Testing

@Suite struct IdleStateMachineTests {
    @Test("normal workflow untagged")
    func normalWorkflowUntagged() {
        var machine = ClientStateMachine.Idle(tag: "A1")

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
        var machine = ClientStateMachine.Idle(tag: "A1")

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
        var machine = ClientStateMachine.Idle(tag: "A1")
        #expect(throws: Never.self) { try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }

        // server cannot confirm idle twice
        #expect(throws: UnexpectedContinuationRequest.self) {
            try machine.receiveContinuationRequest(.responseText(.init(text: "OK")))
        }
    }

    @Test("send response after finished throws")
    func sendResponseAfterFinishedThrows() {
        var machine = ClientStateMachine.Idle(tag: "A1")
        #expect(throws: Never.self) { try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))) }
        machine.sendCommand(.idleDone)

        let badResponse = Response.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "ok"))))
        #expect(throws: UnexpectedResponse.self) {
            try machine.receiveResponse(badResponse)
        }
    }

    /// How `Idle` handles each kind of response, before and after the server's `+`.
    ///
    /// Untagged data may arrive throughout (RFC 2177 §3 shows `* 2 EXPUNGE` ahead of `+`). The
    /// IDLE's own tagged response before `+` is a rejection. After `+`, the server must wait for
    /// DONE, so a tagged response is a protocol violation.
    static let rules: [Rule] = [
        Rule(
            "untagged",
            .untagged(.mailboxData(.exists(3))),
            before: .returns(.continueIdling),
            after: .returns(.continueIdling)
        ),
        Rule("fetch", .fetch(.start(1)), before: .returns(.continueIdling), after: .returns(.continueIdling)),
        Rule(
            "tagged NO for IDLE",
            .tagged(.init(tag: "A1", state: .no(.init(text: "no")))),
            before: .returns(.rejected),
            after: .throws(.idleRunning)
        ),
        Rule(
            "tagged BAD for IDLE",
            .tagged(.init(tag: "A1", state: .bad(.init(text: "bad")))),
            before: .returns(.rejected),
            after: .throws(.idleRunning)
        ),
        Rule(
            "tagged OK for IDLE",
            .tagged(.init(tag: "A1", state: .ok(.init(text: "ok")))),
            before: .returns(.rejected),
            after: .throws(.idleRunning)
        ),
        Rule(
            "tagged for another command",
            .tagged(.init(tag: "A2", state: .ok(.init(text: "ok")))),
            before: .throws(.idleWaitingForConfirmation),
            after: .throws(.idleRunning)
        ),
        Rule(
            "fatal",
            .fatal(.init(text: "Autologout")),
            before: .throws(.idleWaitingForConfirmation),
            after: .throws(.idleRunning)
        ),
        Rule(
            "authentication challenge",
            .authenticationChallenge(ByteBuffer()),
            before: .throws(.idleWaitingForConfirmation),
            after: .throws(.idleRunning)
        ),
        Rule("idle started", .idleStarted, before: .throws(.idleWaitingForConfirmation), after: .throws(.idleRunning)),
    ]

    @Test("response handling", arguments: rules)
    func responseHandling(_ rule: Rule) throws {
        var machine = ClientStateMachine.Idle(tag: "A1")
        #expect(machine.isWaitingForContinuationRequest)
        Self.expect(machine, receiving: rule.response, rule.beforeConfirmation)

        try machine.receiveContinuationRequest(.responseText(.init(text: "idling")))
        #expect(!machine.isWaitingForContinuationRequest)
        Self.expect(machine, receiving: rule.response, rule.afterConfirmation)
    }

    struct Rule: Sendable, CustomTestStringConvertible {
        enum Outcome: Sendable {
            case returns(ClientStateMachine.Idle.ReceiveResponseResult)
            case `throws`(UnexpectedResponse.Kind)
        }

        var testDescription: String
        var response: Response
        var beforeConfirmation: Outcome
        var afterConfirmation: Outcome

        init(_ description: String, _ response: Response, before: Outcome, after: Outcome) {
            self.testDescription = description
            self.response = response
            self.beforeConfirmation = before
            self.afterConfirmation = after
        }
    }

    private static func expect(
        _ machine: ClientStateMachine.Idle,
        receiving response: Response,
        _ outcome: Rule.Outcome,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        switch outcome {
        case .returns(let result):
            do {
                #expect(try machine.receiveResponse(response) == result, sourceLocation: sourceLocation)
            } catch {
                Issue.record(error, sourceLocation: sourceLocation)
            }
        case .throws(let kind):
            let error = #expect(throws: UnexpectedResponse.self, sourceLocation: sourceLocation) {
                try machine.receiveResponse(response)
            }
            #expect(error?.kind == kind, sourceLocation: sourceLocation)
        }
    }
}
