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

        mutating func sendCommand(_ command: CommandStreamPart) -> Bool {
            switch self.state {
            case .idling:
                break
            case .waitingForConfirmation:
                preconditionFailure("Invalid state: \(self.state)")
            }

            switch command {
            case .idleDone:
                return true
            case .tagged, .append, .continuationResponse:
                preconditionFailure("Invalid command for idle state")
            }
        }

        mutating func receiveResponse(_ response: Response) throws {
            switch self.state {
            case .waitingForConfirmation:
                throw UnexpectedResponse()
            case .idling:
                try self.receiveResponse_idlingState(response)
            }
        }

        mutating func receiveContinuationRequest(_: ContinuationRequest) throws {
            switch self.state {
            case .waitingForConfirmation:
                self.state = .idling
            case .idling:
                throw UnexpectedContinuationRequest()
            }
        }

        private func receiveResponse_idlingState(_ response: Response) throws {
            assert(self.state == .idling)
            switch response {
            case .untagged:
                break
            case .fetch, .tagged, .fatal, .authenticationChallenge, .idleStarted:
                throw UnexpectedResponse()
            }
        }
    }
}
