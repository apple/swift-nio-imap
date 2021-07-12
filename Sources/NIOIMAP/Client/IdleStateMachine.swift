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

public struct InvalidCommandForState: Error, Hashable {
    public init() {}
}

extension ClientStateMachine {
    struct Idle: Hashable {
        private enum State: Hashable {
            case waitingForConfirmation
            case idling
            case finished
        }

        private var state: State = .waitingForConfirmation

        var finished: Bool {
            switch self.state {
            case .waitingForConfirmation, .idling:
                return false
            case .finished:
                return true
            }
        }

        mutating func sendCommand(_ command: CommandStreamPart) throws {
            switch self.state {
            case .idling:
                break
            case .waitingForConfirmation, .finished:
                throw InvalidClientState()
            }

            switch command {
            case .tagged, .append, .continuationResponse:
                throw InvalidCommandForState()
            case .idleDone:
                self.state = .finished
            }
        }

        mutating func receiveResponse(_ response: Response) throws {
            switch self.state {
            case .waitingForConfirmation:
                try self.receiveResponse_waiting(response)
            case .idling:
                try self.receiveResponse_idling(response)
            case .finished:
                try self.receiveResponse_finished()
            }
        }

        private mutating func receiveResponse_waiting(_ response: Response) throws {
            switch response {
            case .idleStarted:
                self.state = .idling
            case .fetchResponse, .taggedResponse, .fatalResponse, .authenticationChallenge, .untaggedResponse:
                throw UnexpectedResponse()
            }
        }

        private func receiveResponse_idling(_ response: Response) throws {
            switch response {
            case .untaggedResponse:
                break
            case .fetchResponse, .taggedResponse, .fatalResponse, .authenticationChallenge, .idleStarted:
                throw UnexpectedResponse()
            }
        }

        private func receiveResponse_finished() throws {
            throw UnexpectedResponse()
        }
    }
}
