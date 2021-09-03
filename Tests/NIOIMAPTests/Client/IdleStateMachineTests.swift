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

class IdleStateMachineTests: XCTestCase {
    func testNormalWorkflow() {
        var machine = ClientStateMachine.Idle()

        // server confirms idle
        XCTAssertNoThrow(try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))))

        // server is allowed to send untagged responses while idle
        XCTAssertNoThrow(try machine.receiveResponse(.untagged(.id(["Key1": "Value1"]))))
        XCTAssertNoThrow(try machine.receiveResponse(.untagged(.id(["Key2": "Value2"]))))
        XCTAssertNoThrow(try machine.receiveResponse(.untagged(.id(["Key3": "Value3"]))))

        // user ends idle
        XCTAssertNoThrow(try machine.sendCommand(.idleDone))
    }

    func testMultipleIdleConfirmationsThrowsError() {
        var machine = ClientStateMachine.Idle()
        XCTAssertNoThrow(try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))))

        // server cannot confirm idle twice
        XCTAssertThrowsError(try machine.receiveContinuationRequest(.responseText(.init(text: "OK")))) { e in
            XCTAssertTrue(e is UnexpectedContinuationRequest)
        }
    }

    func testSendingCommandWhileIdleThrowsErrors() {
        var machine = ClientStateMachine.Idle()
        XCTAssertNoThrow(try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))))

        XCTAssertThrowsError(try machine.sendCommand(.tagged(.init(tag: "A1", command: .noop)))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    func testIncorrectResponseTypeThrowsError() {
        var machine = ClientStateMachine.Idle()

        // expecting a continuation to confirm idle has started
        // but instead let's send a tagged response
        let badResponse = Response.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "ok"))))
        XCTAssertThrowsError(try machine.receiveResponse(badResponse)) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }

    func testSendResponseAfterFinishedThrows() {
        var machine = ClientStateMachine.Idle()
        XCTAssertNoThrow(try machine.receiveContinuationRequest(.responseText(.init(text: "OK"))))
        XCTAssertNoThrow(try machine.sendCommand(.idleDone))

        let badResponse = Response.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "ok"))))
        XCTAssertThrowsError(try machine.receiveResponse(badResponse)) { e in
            XCTAssertTrue(e is UnexpectedResponse)
        }
    }
}
