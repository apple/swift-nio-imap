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
    struct Append: Hashable {
        enum State: Hashable {
            // TODO: Find a better name than "started".
            /// We've sent the append command to the server, and will now send data
            /// Can move to `.waitingForAppend...` or `catenating`.
            /// `canFinish` is true iff at least one "standard" append, or one catenate
            /// has completed.
            case started(canFinish: Bool)

            /// We want to send a literal to the server, but first need the server to confirm it's ready.
            /// When we receive the continuation request, we'll move to `.sendingMessageBytes`.
            case waitingForAppendContinuationRequest

            /// We're streaming a message to the server.
            /// Once the message has been sent, we return to `.started`.
            case sendingMessageBytes

            /// We're catenating messages or URLS. No state transformation is required for URLs, as they're
            /// done in one shot, but to catenate a message we need to move to `.waitingForCatenate...`
            case catenating(sentFirstObject: Bool)

            /// We want to send a literal to the server, but first need the server to confirm it's ready.
            /// Once we've received the continuation, we'll move to `.sendingCatenateBytes`.
            case waitingForCatenateContinuationRequest

            /// We're streaming a catenate message to the server. Once the
            /// message is sent we return to `.started`.
            case sendingCatenateBytes

            /// The client has sent the "finish" command, we just need the server to confirm.
            /// From here we move to `finished`.
            case waitingForTaggedResponse

            /// The server has returned a tagged response to finish the append command. No
            /// valid state transformations at this point.
            case finished
        }

        var state: State = .started(canFinish: false)
        
        var hasCatenatedAtLeastOneObject: Bool {
            switch self.state {
            case .started, .waitingForAppendContinuationRequest, .sendingMessageBytes, .waitingForCatenateContinuationRequest, .sendingCatenateBytes, .waitingForTaggedResponse, .finished:
                return false
            case .catenating(sentFirstObject: let sentFirstObject):
                return sentFirstObject
            }
        }

        // We don't expect any responses when appending other than the
        // final tagged response.
        mutating func receiveResponse(_ response: Response) throws -> Bool {
            switch self.state {
            case .started, .waitingForAppendContinuationRequest, .sendingMessageBytes, .catenating,
                 .waitingForCatenateContinuationRequest, .sendingCatenateBytes, .finished:
                throw UnexpectedContinuationRequest()
            case .waitingForTaggedResponse:
                break
            }

            switch response {
            case .untagged, .fetch, .fatal, .authenticationChallenge, .idleStarted:
                throw UnexpectedResponse()
            case .tagged:
                self.state = .finished
                return true
            }
        }

        mutating func receiveContinuationRequest(_: ContinuationRequest) throws {
            switch self.state {
            case .started, .sendingMessageBytes, .catenating,
                 .sendingCatenateBytes, .finished, .waitingForTaggedResponse:
                throw UnexpectedResponse()
            case .waitingForAppendContinuationRequest:
                self.state = .sendingMessageBytes
            case .waitingForCatenateContinuationRequest:
                self.state = .sendingCatenateBytes
            }
        }

        mutating func sendCommand(_ command: CommandStreamPart) {
            // we only care about append commands, obviously
            let appendCommand: AppendCommand
            switch command {
            case .idleDone, .tagged, .continuationResponse:
                preconditionFailure("Invalid command for state: \(self.state)")
            case .append(let _appendCommand):
                appendCommand = _appendCommand
            }

            switch self.state {
            case .waitingForTaggedResponse, .waitingForAppendContinuationRequest, .waitingForCatenateContinuationRequest, .finished:
                preconditionFailure("Invalid state: \(self.state)")
            case .started:
                self.sendCommand_startedState(appendCommand)
            case .sendingMessageBytes:
                self.sendCommand_sendingMessageBytesState(appendCommand)
            case .catenating:
                self.sendCommand_catenatingState(appendCommand)
            case .sendingCatenateBytes:
                self.sendCommand_sendingCatenateBytesState(appendCommand)
            }
        }
    }
}

// MARK: - Send

extension ClientStateMachine.Append {
    private mutating func sendCommand_startedState(_ command: AppendCommand) {
        switch command {
        case .start, .messageBytes, .endMessage, .catenateURL, .catenateData, .endCatenate:
            preconditionFailure("Invalid command for state: \(self.state)")
        case .beginMessage:
            self.state = .waitingForAppendContinuationRequest
        case .beginCatenate:
            self.state = .catenating(sentFirstObject: false)
        case .finish:
            if self.state == .started(canFinish: true) {
                self.state = .waitingForTaggedResponse
            } else {
                preconditionFailure("Invalid command for state: \(self.state)")
            }
        }
    }

    private mutating func sendCommand_sendingMessageBytesState(_ command: AppendCommand) {
        switch command {
        case .start, .beginMessage, .beginCatenate, .catenateURL, .catenateData, .endCatenate, .finish:
            preconditionFailure("Invalid command for state: \(self.state)")
        case .endMessage:
            self.state = .started(canFinish: true)
        case .messageBytes:
            self.state = .sendingMessageBytes // continue sending bytes until we're told to stop
        }
    }

    private mutating func sendCommand_catenatingState(_ command: AppendCommand) {
        switch command {
        case .start, .beginMessage, .beginCatenate, .messageBytes, .endMessage, .finish, .catenateData(.bytes), .catenateData(.end):
            preconditionFailure("Invalid command for state: \(self.state)")
        case .catenateURL:
            self.state = .catenating(sentFirstObject: true)
        case .catenateData(.begin):
            self.state = .waitingForCatenateContinuationRequest
        case .endCatenate:
            self.state = .started(canFinish: true)
        }
    }

    private mutating func sendCommand_sendingCatenateBytesState(_ command: AppendCommand) {
        switch command {
        case .start, .beginMessage, .beginCatenate, .endMessage, .catenateURL, .messageBytes, .finish, .endCatenate, .catenateData(.begin):
            preconditionFailure("Invalid command for state: \(self.state)")
        case .catenateData(.end):
            self.state = .catenating(sentFirstObject: true)
        case .catenateData(.bytes):
            self.state = .sendingCatenateBytes // continue sending bytes until we're told to stop
        }
    }
}
