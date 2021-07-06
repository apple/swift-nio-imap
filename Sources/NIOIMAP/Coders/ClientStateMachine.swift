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
    public init() { }
}

enum State: Hashable {
    case expectingNormalResponse
    case idle(IdleState)
    case authenticating
    case expectingLiteralContinuationRequest
    case completingCommand
    case error
    case appending
    case startedAppendMessage
    case startedCatenateMessage
}

enum IdleState: Hashable {
    case expectingConfirmation
    case idling
}

struct ClientStateMachine: Hashable {

    private var state: State = .expectingNormalResponse

    mutating func receiveResponse(_ response: Response) throws {
        switch self.state {
        case .idle:
            try self.receiveResponse_idle(response)
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
    private mutating func sendCommand_normalResponse(_ command: CommandStreamPart) throws {
        switch command {
        case .tagged(let tagged):
            try self.sendCommandTagged_normalResponse(tagged)
        case .idleDone, .continuationResponse:
            throw InvalidClientState()
        default:
            fatalError("TODO")
        }
    }

    private mutating func sendCommandTagged_normalResponse(_ command: TaggedCommand) throws {
        switch command.command {
        case .idleStart:
            self.state = .idle(.expectingConfirmation)
        default:
            break
        }
    }

    private mutating func sendCommand_idle(_ command: CommandStreamPart) throws {
        switch command {
        case .idleDone:
            guard self.state == .idle(.idling) else {
                throw InvalidClientState()
            }
            self.state = .expectingNormalResponse
            return
        default:
            throw InvalidClientState()
        }
    }
}

// MARK: - Receive

extension ClientStateMachine {
    private mutating func receiveResponse_idle(_ response: Response) throws {
        switch self.state {
        case .idle(.idling):
            // only untagged responses are allowed while idling
            break
        case .idle(.expectingConfirmation):
            self.state = .idle(.idling)
        default:
            preconditionFailure("Expected an idle state")
        }
    }
}
