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

public struct InvalidCommandForState: Error, Equatable {
    public var command: CommandStreamPart

    public init(_ command: CommandStreamPart) {
        self.command = command
    }
}

struct ClientStateMachine: Hashable {
    enum State: Hashable {
        case expectingNormalResponse
        case idle(ClientStateMachine.Idle)
        case authenticating(ClientStateMachine.Authentication)
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
        case .idle(var idleStateMachine):
            self.state = try idleStateMachine.receiveResponse(response)
        case .authenticating(var authStateMachine):
            self.state = try authStateMachine.receiveResponse(response)
        default:
            fatalError("TODO")
        }
    }

    mutating func sendCommand(_ command: CommandStreamPart) throws {
        switch self.state {
        case .expectingNormalResponse:
            try self.sendCommand_state_normalResponse(command: command)
        case .idle(var idleStateMachine):
            self.state = try idleStateMachine.sendCommand(command)
        case .authenticating(var authStateMachine):
            self.state = try authStateMachine.sendCommand(command)
        default:
            fatalError("TODO")
        }
    }
}

// MARK: - Send

extension ClientStateMachine {
    private mutating func sendCommand_state_normalResponse(command: CommandStreamPart) throws {
        assert(self.state == .expectingNormalResponse)

        switch command {
        case .idleDone, .continuationResponse:
            throw InvalidCommandForState(command)
        case .tagged(let tc):
            try self.sendTaggedCommand(tc)
        case .append:
            fatalError("TODO")
        }
    }

    private mutating func sendTaggedCommand(_ command: TaggedCommand) throws {
        assert(self.state == .expectingNormalResponse)

        // it's not practical to switch over
        // every command here, there are over
        // 50 of them...
        switch command.command {
        case .idleStart:
            self.state = .idle(Idle())
        case .authenticate:
            self.state = .authenticating(Authentication())
        default:
            break
        }
    }
}
