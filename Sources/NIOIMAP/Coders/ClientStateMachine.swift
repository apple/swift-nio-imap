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
        case .expectingNormalResponse:
            break
        case .idle:
            try self.receiveResponse_idle(response)
        case .authenticating:
            break
        case .expectingLiteralContinuationRequest:
            try self.receiveResponse_expectingContinuationRequest(response)
        case .completingCommand:
            break
        case .error:
            break
        case .appending:
            break
        case .startedAppendMessage:
            break
        case .startedCatenateMessage:
            break
        }
    }
    
    mutating func sendCommand(_ command: CommandStreamPart) throws {
        switch self.state {
        case .expectingNormalResponse:
            try self.sendCommand_normalResponse(command)
        case .idle:
            try self.sendCommand_idle(command)
        case .authenticating:
            try self.sendCommand_normalResponse(command)
        case .expectingLiteralContinuationRequest:
            try self.sendCommand_normalResponse(command)
        case .completingCommand:
            try self.sendCommand_normalResponse(command)
        case .error:
            try self.sendCommand_normalResponse(command)
        case .appending:
            try self.sendCommand_normalResponse(command)
        case .startedAppendMessage:
            try self.sendCommand_normalResponse(command)
        case .startedCatenateMessage:
            try self.sendCommand_normalResponse(command)
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
        case .append(let append):
            try self.sendCommandAppend_normalResponse(append)
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
    
    mutating private func sendCommandAppend_normalResponse(_ command: AppendCommand) throws {
        
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
    
    private func sendCommand_authenticating(_ command: CommandStreamPart) throws {
        
    }
    
    private func sendCommand_expectingLiteralContinuationRequest(_ command: CommandStreamPart) throws {
        
    }
    
    private func sendCommand_completingCommand(_ command: CommandStreamPart) throws {
        
    }
    
    private func sendCommand_error(_ command: CommandStreamPart) throws {
        
    }
    
    private func sendCommand_appending(_ command: CommandStreamPart) throws {
        
    }
    
    private func sendCommand_startedAppendMessage(_ command: CommandStreamPart) throws {
        
    }
    
    private func sendCommand_startedCatenateMessage(_ command: CommandStreamPart) throws {
        
    }

}

// MARK: - Receive
extension ClientStateMachine {
    
    mutating private func receiveResponse_idle(_ response: Response) throws {
        switch response {
        case .untaggedResponse(_):
            break
        case .fetchResponse(_):
            break
        case .taggedResponse(_):
            break
        case .fatalResponse(_):
            break
        case .authenticationChallenge(_):
            break
        case .idleStarted:
            try self.receiveResponseIdleStarted_idle()
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
