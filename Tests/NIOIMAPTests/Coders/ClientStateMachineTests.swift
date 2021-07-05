//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
@testable import NIOIMAP
@testable import NIOIMAPCore
import XCTest

class ClientStateMachineTests: XCTestCase { }

// MARK: - IDLE
extension ClientStateMachineTests {
    
    func testIdleWorkflow_normal() {
        
        // set up the state machine, show we can send a command
        var stateMachine = ClientStateMachine()
        XCTAssertNoThrow(try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .noop))))
        
        // 1. start idle
        // 2. server confirms idle
        // 3. end idle
        XCTAssertNoThrow(try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .idleStart))))
        XCTAssertNoThrow(try stateMachine.receiveResponse(.idleStarted))
        XCTAssertNoThrow(try stateMachine.sendCommand(.idleDone))
        
        // state machine should have reset, so we can send a normal command again
        XCTAssertNoThrow(try stateMachine.sendCommand(.tagged(.init(tag: "A3", command: .noop))))
    }
    
    func testIdleWorkflow_noEnd() {
        // set up the state machine to idle
        var stateMachine = ClientStateMachine()
        XCTAssertNoThrow(try stateMachine.sendCommand(.tagged(.init(tag: "A1", command: .idleStart))))
        XCTAssertNoThrow(try stateMachine.receiveResponse(.idleStarted))
        
        // machine is idle, so sending a different command should throw
        XCTAssertThrowsError(try stateMachine.sendCommand(.tagged(.init(tag: "A2", command: .noop)))) { e in
            XCTAssertTrue(e is InvalidClientState)
        }
    }
    
}
