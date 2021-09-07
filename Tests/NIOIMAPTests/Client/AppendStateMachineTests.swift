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
        self.stateMachine.sendCommand(.append(.beginMessage(message: .init(options: .init(), data: .init(byteCount: 10)))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        self.stateMachine.sendCommand(.append(.messageBytes("12345")))
        self.stateMachine.sendCommand(.append(.messageBytes("67890")))
        self.stateMachine.sendCommand(.append(.endMessage))

        // catenate a message
        self.stateMachine.sendCommand(.append(.beginCatenate(options: .init())))
        self.stateMachine.sendCommand(.append(.catenateURL("url1")))
        self.stateMachine.sendCommand(.append(.catenateURL("url2")))
        self.stateMachine.sendCommand(.append(.catenateURL("url3")))
        self.stateMachine.sendCommand(.append(.catenateData(.begin(size: 10))))
        XCTAssertNoThrow(try self.stateMachine.receiveContinuationRequest(.data("req")))
        self.stateMachine.sendCommand(.append(.messageBytes("12345")))
        self.stateMachine.sendCommand(.append(.messageBytes("67890")))
        self.stateMachine.sendCommand(.append(.endCatenate))

        self.stateMachine.sendCommand(.append(.finish))
        XCTAssertNoThrow(XCTAssertEqual(try self.stateMachine.receiveResponse(.tagged(.init(tag: "A1", state: .ok(.init(code: nil, text: "OK"))))), true)
        )
    }
}
