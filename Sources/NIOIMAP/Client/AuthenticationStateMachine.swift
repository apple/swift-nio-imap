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
            case authenticating
            case finished
        }

        private var state: State = .authenticating

        mutating func receiveResponse(_ response: Response) throws -> ClientStateMachine.State {
            switch self.state {
            case .finished:
                throw UnexpectedResponse()
            case .authenticating:
                break
            }

            switch response {
            case .untagged, .fetch, .fatal, .idleStarted:
                throw UnexpectedResponse()
            case .tagged:
                return try self.handleTaggedResponse()
            case .authenticationChallenge:
                return .authenticating(self)
            }
        }

        // we don't care about the specific response
        private mutating func handleTaggedResponse() throws -> ClientStateMachine.State {
            self.state = .finished
            return .expectingNormalResponse
        }

        // we don't care about the specific response
        private mutating func handleAuthenticationChallenge(_: Response) throws -> ClientStateMachine.State {
            self.state = .authenticating
            return .authenticating(self)
        }

        mutating func sendCommand(_ command: CommandStreamPart) throws -> ClientStateMachine.State {
            switch self.state {
            case .finished:
                throw InvalidCommandForState(command)
            case .authenticating:
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
            self.state = .authenticating
            return .authenticating(self)
        }
    }
}
