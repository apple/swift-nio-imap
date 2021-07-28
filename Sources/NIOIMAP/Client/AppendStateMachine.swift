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
            /// We've sent the append command to the server, and will now send data
            /// Can move to `.waitingForAppend...` or `catenating`
            case started

            /// We want to send a literal to the server, but first need the server to confirm it's ready.
            /// When we receive the continuation request, we'll move to `.sendingMessageBytes`.
            case waitingForAppendContinuationRequest

            /// We're streaming a message to the server.
            /// Once the message has been sent, we return to `.started`.
            case sendingMessageBytes

            /// We're catenating messages or URLS. No state transformation is required for URLs, as they're
            /// done in one shot, but to catenate a message we need to move to `.waitingForCatenate...`
            case catenating

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

        var state: State = .started

        // we don't expect any responses when appending
        mutating func receiveResponse(_ response: Response) throws -> ClientStateMachine.State {
            switch self.state {
            case .started, .waitingForAppendContinuationRequest, .sendingMessageBytes, .catenating,
                 .waitingForCatenateContinuationRequest, .sendingCatenateBytes, .finished:
                throw UnexpectedResponse()
            case .waitingForTaggedResponse:
                break
            }

            switch response {
            case .untagged, .fetch, .fatal, .authenticationChallenge, .idleStarted:
                throw UnexpectedResponse()
            case .tagged:
                self.state = .finished
                return .expectingNormalResponse
            }
        }

        mutating func receiveContinuationRequest(_: ContinuationRequest) throws -> ClientStateMachine.State {
            switch self.state {
            case .started, .sendingMessageBytes, .catenating,
                 .sendingCatenateBytes, .finished, .waitingForTaggedResponse:
                throw UnexpectedResponse()
            case .waitingForAppendContinuationRequest:
                self.state = .sendingMessageBytes
            case .waitingForCatenateContinuationRequest:
                self.state = .sendingCatenateBytes
            }
            return .appending(self)
        }

        mutating func sendCommand(_ command: CommandStreamPart) throws -> ClientStateMachine.State {
            // we only care about append commands, obviously
            let appendCommand: AppendCommand
            switch command {
            case .idleDone, .tagged, .continuationResponse:
                throw InvalidCommandForState(command)
            case .append(let _appendCommand):
                appendCommand = _appendCommand
            }

            switch self.state {
            case .waitingForTaggedResponse, .waitingForAppendContinuationRequest, .waitingForCatenateContinuationRequest, .finished:
                throw InvalidCommandForState(command)
            case .started:
                return try self.sendCommand_startedState(appendCommand)
            case .sendingMessageBytes:
                return try self.sendCommand_sendingMessageBytesState(appendCommand)
            case .catenating:
                return try self.sendCommand_catenatingState(appendCommand)
            case .sendingCatenateBytes:
                return try self.sendCommand_sendingCatenateBytesState(appendCommand)
            }
        }
    }
}

// MARK: - Send

extension ClientStateMachine.Append {
    private mutating func sendCommand_startedState(_ command: AppendCommand) throws -> ClientStateMachine.State {
        switch command {
        case .start, .messageBytes, .endMessage, .catenateURL, .catenateData, .endCatenate:
            throw InvalidCommandForState(.append(command))
        case .beginMessage:
            self.state = .waitingForAppendContinuationRequest
        case .beginCatenate:
            self.state = .catenating
        case .finish:
            throw InvalidCommandForState(.append(command))
        }
        return .appending(self)
    }

    private mutating func sendCommand_sendingMessageBytesState(_ command: AppendCommand) throws -> ClientStateMachine.State {
        switch command {
        case .start, .beginMessage, .beginCatenate, .catenateURL, .catenateData, .endCatenate, .finish:
            throw InvalidCommandForState(.append(command))
        case .endMessage:
            self.state = .started
        case .messageBytes:
            self.state = .sendingMessageBytes // continue sending bytes until we're told to stop
        }
        return .appending(self)
    }

    private mutating func sendCommand_catenatingState(_ command: AppendCommand) throws -> ClientStateMachine.State {
        switch command {
        case .start, .beginMessage, .beginCatenate, .messageBytes, .endMessage, .finish:
            throw InvalidCommandForState(.append(command))
        case .catenateURL:
            self.state = .catenating
        case .catenateData:
            self.state = .waitingForCatenateContinuationRequest
        case .endCatenate:
            self.state = .started
        }
        return .appending(self)
    }

    private mutating func sendCommand_sendingCatenateBytesState(_ command: AppendCommand) throws -> ClientStateMachine.State {
        switch command {
        case .start, .beginMessage, .beginCatenate, .endMessage, .catenateURL, .catenateData, .finish:
            throw InvalidCommandForState(.append(command))
        case .endCatenate:
            self.state = .started
        case .messageBytes:
            self.state = .sendingCatenateBytes // continue sending bytes until we're told to stop
        }
        return .appending(self)
    }
}
