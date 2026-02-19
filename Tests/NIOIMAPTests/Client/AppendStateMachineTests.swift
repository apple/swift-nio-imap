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

@Suite struct AppendStateMachineTests {
    var stateMachine: ClientStateMachine.Append!

    init() {
        self.stateMachine = .init(tag: "A1")
    }

    @Test("normal workflow")
    mutating func normalWorkflow() {
        // append a message
        self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
        )
        #expect(self.stateMachine.isWaitingForContinuationRequest)

        #expect(throws: Never.self) { try self.stateMachine.receiveContinuationRequest(.data("req")) }
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.messageBytes("12345")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.messageBytes("67890")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.endMessage))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.finish))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        var result: ClientStateMachine.Append.ReceiveResponseResult?
        #expect(throws: Never.self) {
            result = try self.stateMachine.receiveResponse(
                .tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))
            )
        }
        #expect(result == .doneAppending)
    }

    @Test("normal workflow catenate")
    mutating func normalWorkflowCatenate() {
        // append a message
        self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
        )
        #expect(self.stateMachine.isWaitingForContinuationRequest)

        #expect(throws: Never.self) { try self.stateMachine.receiveContinuationRequest(.data("req")) }
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        // "Normal"
        self.stateMachine.sendCommand(.append(.messageBytes("12345")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.messageBytes("67890")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.endMessage))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        // Catenate
        self.stateMachine.sendCommand(.append(.beginCatenate(options: .init())))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateURL("url1")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateURL("url2")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateURL("url3")))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10))))
        #expect(self.stateMachine.isWaitingForContinuationRequest)

        #expect(throws: Never.self) { try self.stateMachine.receiveContinuationRequest(.data("req")) }
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.bytes("12345"))))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.bytes("67890"))))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.end)))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.endCatenate))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.finish))
        #expect(!self.stateMachine.isWaitingForContinuationRequest)

        var result: ClientStateMachine.Append.ReceiveResponseResult?
        #expect(throws: Never.self) {
            result = try self.stateMachine.receiveResponse(
                .tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))
            )
        }
        #expect(result == .doneAppending)
    }

    @Test("receiving untagged while waiting for continuation request")
    mutating func receivingUntaggedWhileWaitingForContinuationRequest() throws {
        // append a message
        self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
        )
        #expect(self.stateMachine.isWaitingForContinuationRequest)

        // At this point, we're waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A003 APPEND saved-messages (\Seen) {310}
        // S: * 3 EXPUNGE
        // S: + Ready for literal data
        // C: Date: Mon, 7 Feb 1994 21:52:25 -0800 (PST)
        // C: From: Fred Foobar <foobar@Blurdybloop.COM>
        // ``

        #expect(throws: Never.self, "Should be ignored.") {
            try self.stateMachine.receiveResponse(.untagged(.messageData(.expunge(3))))
        }
        #expect(throws: Never.self) { try self.stateMachine.receiveContinuationRequest(.data("req")) }
        #expect(!self.stateMachine.isWaitingForContinuationRequest)
    }
}
