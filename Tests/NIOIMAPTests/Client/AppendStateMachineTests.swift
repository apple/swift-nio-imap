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
        self.stateMachine = .init()
    }

    func testNormalWorkflow() {
        // append a message
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("12345"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("67890"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.endMessage)))

        // catenate a message
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginCatenate(options: .init()))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateURL("url1"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateURL("url2"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateURL("url3"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10)))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("12345"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.messageBytes("67890"))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.endCatenate)))

        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.finish)))
    }

    func testStartAppendWhenCatenatingThrows() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginCatenate(options: .init()))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(
            .append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10)))))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    func testNotWaitingForContinuationThrows() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10))))))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.append(.messageBytes("message")))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }

    // we can't catenate a URL while we're meant to
    // be sending bytes
    func testMixingCatenateTypesThrows() {
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.beginCatenate(options: .init()))))
        XCTAssertNoThrow(try self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10)))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        XCTAssertThrowsError(try self.stateMachine.sendCommand(.append(.catenateURL("url")))) { e in
            XCTAssertTrue(e is InvalidCommandForState)
        }
    }
}
