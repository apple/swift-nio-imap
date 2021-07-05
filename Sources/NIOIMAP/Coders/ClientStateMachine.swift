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

import NIO
import NIOIMAPCore

public struct InvalidClientState: Error {
    public init() { }
}

struct ClientStateMachine: Hashable {
    
    enum State: Hashable {
        case expectingNormalResponse
        case idle
        case authenticating
        case expectingLiteralContinuationRequest
        case completingCommand
        case error
        case appending
        case startedAppendMessage
        case startedCatenateMessage
    }
    
    private var stateStack: [State] = [.expectingNormalResponse]
    
    private var state: State {
        self.stateStack.last!
    }
    
    mutating func receiveResponse(_ response: Response) throws {
        switch self.state {
        case .idle:
            try self.receiveResponse_idle(response)
        case .expectingLiteralContinuationRequest:
            try self.receiveResponse_expectingContinuationRequest(response)
        default:
            fatalError("TODO")
        }
    }
    
    mutating func sendCommand(_ command: CommandStreamPart) throws {
        switch self.state {
        case .expectingNormalResponse:
            try self.sendCommand_normalResponse(command)
        case .idle:
            try self.sendCommand_idle(command)
        default:
            fatalError("TODO")
        }
    }
}

// MARK: - Send
extension ClientStateMachine {
    
    mutating private func sendCommand_normalResponse(_ command: CommandStreamPart) throws {
        switch command {
        case .tagged(let tagged):
            try self.sendCommandTagged_normalResponse(tagged)
        case .idleDone, .continuationResponse:
            throw InvalidClientState()
        default:
            fatalError("TODO")
        }
    }
    
    mutating private func sendCommandTagged_normalResponse(_ command: TaggedCommand) throws {
        switch command.command {
        case .idleStart:
            self.stateStack.append(contentsOf: [.idle, .expectingLiteralContinuationRequest])
        default:
            break
        }
    }
    
    mutating private func sendCommand_idle(_ command: CommandStreamPart) throws {
        switch command {
        case .idleDone:
            guard self.state == .idle else {
                throw InvalidClientState()
            }
            _ = self.stateStack.popLast()
            return
        default:
            throw InvalidClientState()
        }
    }

}

// MARK: - Receive
extension ClientStateMachine {
    
    mutating private func receiveResponse_idle(_ response: Response) throws {
        switch response {
        case .idleStarted:
            try self.receiveResponseIdleStarted_idle()
        default:
            fatalError("TODO")
        }
    }
    
    mutating private func receiveResponse_expectingContinuationRequest(_ response: Response) throws {
        assert(self.stateStack.count >= 2, "Must have a state to return to.")
        guard self.state == .expectingLiteralContinuationRequest else {
            throw InvalidClientState()
        }
        _ = self.stateStack.popLast()
    }
    
    mutating private func receiveResponseIdleStarted_idle() throws {
        assert(self.stateStack.count >= 2)
        guard self.stateStack.popLast() == .expectingLiteralContinuationRequest else {
            throw InvalidClientState()
        }
    }
    
}
