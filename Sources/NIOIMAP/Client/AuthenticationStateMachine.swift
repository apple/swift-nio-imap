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

extension ClientStateMachine {
    struct Authentication: Hashable {
        enum State: Hashable {
            /// The client has sent the authentiction command
            /// and is now waiting for either a server challenge
            /// or for the server to confirm authentication is
            /// complete.
            case waitingForServer

            /// We've received a server challenge, and now the client
            /// needs to respond.
            case waitingForChallengeResponse

            /// We've received a tagged response from the
            /// server, signalling that authentication is
            /// finished.
            case finished
        }

        private var state: State = .waitingForServer

        mutating func receiveResponse(_ response: Response) throws -> ClientStateMachine.State {
            switch self.state {
            case .finished, .waitingForChallengeResponse:
                throw UnexpectedResponse()
            case .waitingForServer:
                break
            }

            switch response {
            case .untagged, .fetch, .fatal, .idleStarted:
                throw UnexpectedResponse()
            case .tagged:
                return try self.handleTaggedResponse()
            case .authenticationChallenge:
                return try self.handleAuthenticationChallenge()
            }
        }

        // we don't care about the specific response
        private mutating func handleTaggedResponse() throws -> ClientStateMachine.State {
            self.state = .finished
            return .expectingNormalResponse
        }

        private mutating func handleAuthenticationChallenge() throws -> ClientStateMachine.State {
            self.state = .waitingForChallengeResponse
            return .authenticating(self)
        }

        mutating func sendCommand(_ command: CommandStreamPart) throws -> ClientStateMachine.State {
            switch self.state {
            case .finished, .waitingForServer:
                throw InvalidCommandForState(command)
            case .waitingForChallengeResponse:
                break
            }

            // the only reason to send a command when authenticating
            // is to response to a challenge
            switch command {
            case .idleDone, .tagged, .append:
                throw InvalidCommandForState(command)
            case .continuationResponse:
                break
            }
            self.state = .waitingForServer
            return .authenticating(self)
        }
    }
}
