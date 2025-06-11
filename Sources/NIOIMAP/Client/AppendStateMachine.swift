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

        // The tag of the APPEND command
        var tag: String
        var state: State = .started(canFinish: false)

        var isWaitingForContinuationRequest: Bool {
            switch state {
            case .waitingForAppendContinuationRequest, .waitingForCatenateContinuationRequest:
                true
            case .started, .sendingMessageBytes, .catenating, .sendingCatenateBytes, .waitingForTaggedResponse,
                .finished:
                false
            }
        }

        var hasCatenatedAtLeastOneObject: Bool {
            switch self.state {
            case .started, .waitingForAppendContinuationRequest, .sendingMessageBytes,
                .waitingForCatenateContinuationRequest, .sendingCatenateBytes, .waitingForTaggedResponse, .finished:
                return false
            case .catenating(sentFirstObject: let sentFirstObject):
                return sentFirstObject
            }
        }

        enum ReceiveResponseResult {
            case continueAppending
            case doneAppending
        }

        // We don't expect any responses while appending other than
        // 1. Untagged responses (including untagged fetch responses)
        // 2. The final tagged response.
        mutating func receiveResponse(_ response: Response) throws -> ReceiveResponseResult {
            switch response {
            case .untagged, .fetch:
                return .continueAppending
            case .tagged(let tagged) where tagged.tag != self.tag:
                // This is the completion for another (previous) command. Ignore.
                return .continueAppending
            case .tagged, .fatal, .authenticationChallenge, .idleStarted:
                break
            }

            switch self.state {
            case .started, .waitingForAppendContinuationRequest, .sendingMessageBytes, .catenating,
                .waitingForCatenateContinuationRequest, .sendingCatenateBytes, .finished:
                throw UnexpectedResponse(kind: .appendNotWaitingForTaggedResponse)
            case .waitingForTaggedResponse:
                break
            }

            switch response {
            case .untagged, .fetch, .fatal, .authenticationChallenge, .idleStarted:
                throw UnexpectedResponse(kind: .appendWaitingForTaggedResponse)
            case .tagged:
                self.state = .finished
                return .doneAppending
            }
        }

        mutating func receiveContinuationRequest(_: ContinuationRequest) throws {
            switch self.state {
            case .started, .sendingMessageBytes, .catenating,
                .sendingCatenateBytes, .finished, .waitingForTaggedResponse:
                throw UnexpectedContinuationRequest(kind: .append)
            case .waitingForAppendContinuationRequest:
                self.state = .sendingMessageBytes
            case .waitingForCatenateContinuationRequest:
                self.state = .sendingCatenateBytes
            }
        }

        /// - returns: `true` if a continuation is required after this command is sent, otherwise `false`.
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
            case .waitingForTaggedResponse, .waitingForAppendContinuationRequest,
                .waitingForCatenateContinuationRequest, .finished:
                preconditionFailure("Invalid state: \(self.state)")
            case .started:
                self.sendCommand_startedState(appendCommand)
            case .sendingMessageBytes:
                self.sendCommand_sendingMessageBytesState(appendCommand)
            case .catenating:
                return self.sendCommand_catenatingState(appendCommand)
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
            guard
                self.state == .started(canFinish: true)
            else {
                preconditionFailure("Invalid command for state: \(self.state)")
            }
            self.state = .waitingForTaggedResponse
        }
    }

    private mutating func sendCommand_sendingMessageBytesState(_ command: AppendCommand) {
        switch command {
        case .start, .beginMessage, .beginCatenate, .catenateURL, .catenateData, .endCatenate, .finish:
            preconditionFailure("Invalid command for state: \(self.state)")
        case .endMessage:
            self.state = .started(canFinish: true)
        case .messageBytes:
            self.state = .sendingMessageBytes  // continue sending bytes until we're told to stop
        }
    }

    private mutating func sendCommand_catenatingState(_ command: AppendCommand) {
        switch command {
        case .start, .beginMessage, .beginCatenate, .messageBytes, .endMessage, .finish, .catenateData(.bytes),
            .catenateData(.end):
            preconditionFailure("Invalid command for state: \(self.state)")
        case .catenateURL:
            self.state = .catenating(sentFirstObject: true)
        case .catenateData(.begin):
            self.state = .waitingForCatenateContinuationRequest
        case .endCatenate:
            self.state = .started(canFinish: true)
        }
    }

    /// `true` if a continuation is required, otherwise `false`
    private mutating func sendCommand_sendingCatenateBytesState(_ command: AppendCommand) {
        switch command {
        case .start, .beginMessage, .beginCatenate, .endMessage, .catenateURL, .messageBytes, .finish, .endCatenate,
            .catenateData(.begin):
            preconditionFailure("Invalid command for state: \(self.state)")
        case .catenateData(.end):
            self.state = .catenating(sentFirstObject: true)
        case .catenateData(.bytes):
            self.state = .sendingCatenateBytes  // continue sending bytes until we're told to stop
        }
    }
}
