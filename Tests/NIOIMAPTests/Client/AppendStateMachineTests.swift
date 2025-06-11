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

class AppendStateMachineTests: XCTestCase {
    var stateMachine: ClientStateMachine.Append!

    override func setUp() {
        self.stateMachine = .init(tag: "A1")
    }

    func testNormalWorkflow() {
        // append a message
        self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
        )
        XCTAssert(self.stateMachine.isWaitingForContinuationRequest)

        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.messageBytes("12345")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.messageBytes("67890")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.endMessage))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.finish))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        XCTAssertNoThrow(
            XCTAssertEqual(
                try self.stateMachine.receiveResponse(
                    .tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))
                ),
                .doneAppending
            )
        )
    }

    func testNormalWorkflow_catenate() {
        // append a message
        self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
        )
        XCTAssert(self.stateMachine.isWaitingForContinuationRequest)

        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        // “Normal”
        self.stateMachine.sendCommand(.append(.messageBytes("12345")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.messageBytes("67890")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.endMessage))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        // Catenate
        self.stateMachine.sendCommand(.append(.beginCatenate(options: .init())))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateURL("url1")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateURL("url2")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateURL("url3")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10))))
        XCTAssert(self.stateMachine.isWaitingForContinuationRequest)

        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.bytes("12345"))))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.bytes("67890"))))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.catenateData(.end)))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.endCatenate))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        self.stateMachine.sendCommand(.append(.finish))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)

        XCTAssertNoThrow(
            XCTAssertEqual(
                try self.stateMachine.receiveResponse(
                    .tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))
                ),
                .doneAppending
            )
        )
    }

    func testReceivingUntaggedWhileWaitingForContinuationRequest() throws {
        // append a message
        self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))
        )
        XCTAssert(self.stateMachine.isWaitingForContinuationRequest)

        // At this point, we’re waiting for a Continuation Request from the server.
        // But we may end up getting an untagged response first.
        // ```
        // C: A003 APPEND saved-messages (\Seen) {310}
        // S: * 3 EXPUNGE
        // S: + Ready for literal data
        // C: Date: Mon, 7 Feb 1994 21:52:25 -0800 (PST)
        // C: From: Fred Foobar <foobar@Blurdybloop.COM>
        // ``

        XCTAssertNoThrow(
            try self.stateMachine.receiveResponse(.untagged(.messageData(.expunge(3)))),
            "Should be ignored."
        )
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertFalse(self.stateMachine.isWaitingForContinuationRequest)
    }
}
