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
    public init() {}
}

public struct UnexpectedResponse: Error {
    public init() {}
}

struct ClientStateMachine: Hashable {
    
    enum State: Hashable {
        case expectingNormalResponse
        case idle(ClientStateMachine.Idle)
        case authenticating
        case expectingLiteralContinuationRequest
        case completingCommand
        case error
        case appending
        case startedAppendMessage
        case startedCatenateMessage
    }
    
    private var state: State = .expectingNormalResponse

    mutating func receiveResponse(_ response: Response) throws {
        switch self.state {
        case .idle(let idleStateMachine):
            try self.handleResponse_idle(idleStateMachine: idleStateMachine, response: response)
        default:
            fatalError("TODO")
        }
    }

    mutating func sendCommand(_ command: CommandStreamPart) throws {
        switch self.state {
        case .expectingNormalResponse:
            try self.sendCommand_normalResponse(command: command)
        case .idle(let idleStateMachine):
            try self.sendCommand_idle(idleStateMachine: idleStateMachine, command: command)
        default:
            fatalError("TODO")
        }
    }
}

// MARK: - Receive
extension ClientStateMachine {
    
    private mutating func handleResponse_idle(idleStateMachine: Idle, response: Response) throws {
        var idleStateMachine = idleStateMachine
        try idleStateMachine.receiveResponse(response)
        self.state = .idle(idleStateMachine)
    }
    
}

// MARK: - Send
extension ClientStateMachine {
    
    private mutating func sendCommand_normalResponse(command: CommandStreamPart) throws {
        assert(self.state == .expectingNormalResponse)
        
        switch command {
        case .idleDone, .continuationResponse:
            throw InvalidCommandForState()
        case .tagged(let taggedCommand):
            try self.sendTaggedCommand(command: taggedCommand)
        case .append(_):
            fatalError("TODO")
        }
    }
    
    private mutating func sendTaggedCommand(command: TaggedCommand) throws {
        assert(self.state == .expectingNormalResponse)
        
        switch command.command {
        case .idleStart:
            self.state = .idle(Idle())
        default:
            break
        }
    }
    
    private mutating func sendCommand_idle(idleStateMachine: Idle, command: CommandStreamPart) throws {
        var idleStateMachine = idleStateMachine
        try idleStateMachine.sendCommand(command)
        if idleStateMachine.finished {
            self.state = .expectingNormalResponse
        } else {
            self.state = .idle(idleStateMachine)
        }
    }
    
}
