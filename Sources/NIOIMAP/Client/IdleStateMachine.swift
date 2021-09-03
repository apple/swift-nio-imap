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

import NIOIMAPCore

public struct InvalidIdleState: Error, Hashable {
    public init() {}
}

extension ClientStateMachine {
    struct Idle: Hashable {
        enum State: Hashable {
            case waitingForConfirmation
            case idling
        }

        private var state: State = .waitingForConfirmation

        mutating func sendCommand(_ command: CommandStreamPart) throws -> ClientStateMachine.State {
            switch self.state {
            case .idling:
                break
            case .waitingForConfirmation:
                throw InvalidIdleState()
            }

            switch command {
            case .idleDone:
                return .expectingNormalResponse
            case .tagged, .append, .continuationResponse:
                throw InvalidCommandForState(command)
            }
        }

        mutating func receiveResponse(_ response: Response) throws -> ClientStateMachine.State {
            switch self.state {
            case .waitingForConfirmation:
                throw UnexpectedResponse()
            case .idling:
                return try self.receiveResponse_idlingState(response)
            }
        }
        
        mutating func receiveContinuationRequest(_ request: ContinuationRequest) throws -> ClientStateMachine.State {
            switch self.state {
            case .waitingForConfirmation:
                self.state = .idling
                return .idle(self)
            case .idling:
                throw UnexpectedContinuationRequest()
            }
        }

        private func receiveResponse_idlingState(_ response: Response) throws -> ClientStateMachine.State {
            assert(self.state == .idling)
            switch response {
            case .untagged:
                return .idle(self)
            case .fetch, .tagged, .fatal, .authenticationChallenge, .idleStarted:
                throw UnexpectedResponse()
            }
        }
    }
}
