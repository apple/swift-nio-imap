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
    /// The `IDLE` command (RFC 2177), from `IDLE` until `DONE` or the server's rejection.
    ///
    /// ```
    /// C: A1 IDLE
    /// S: * 3 EXISTS           ← untagged data, allowed throughout
    /// S: + idling             ← confirmation; the server now waits for DONE
    /// C: DONE
    /// ```
    ///
    /// Instead of `+`, the server may reject `IDLE` with its tagged response (`A1 NO …`). After
    /// `+`, it must wait for `DONE`, so a tagged response is a protocol violation.
    struct Idle: Hashable {
        enum State: Hashable {
            case waitingForConfirmation
            case idling
        }

        /// The tag of the IDLE command.
        let tag: String
        private(set) var state: State = .waitingForConfirmation

        init(tag: String) {
            self.tag = tag
        }

        /// `DONE` answers the server's `+`, so it has to wait for it.
        var isWaitingForContinuationRequest: Bool {
            self.state == .waitingForConfirmation
        }

        mutating func sendCommand(_ command: CommandStreamPart) {
            switch self.state {
            case .idling:
                break
            case .waitingForConfirmation:
                preconditionFailure("Invalid state: \(self.state)")
            }

            switch command {
            case .idleDone:
                break
            case .tagged, .append, .continuationResponse:
                preconditionFailure("Invalid command for idle state")
            }
        }

        enum ReceiveResponseResult: Equatable {
            case continueIdling
            /// The server rejected IDLE with its tagged response instead of confirming it.
            case rejected
        }

        func receiveResponse(_ response: Response) throws -> ReceiveResponseResult {
            switch (response, self.state) {
            case (.untagged, _), (.fetch, _):
                return .continueIdling
            case (.tagged(let tagged), .waitingForConfirmation) where tagged.tag == self.tag:
                return .rejected
            case (_, .waitingForConfirmation):
                throw UnexpectedResponse(kind: .idleWaitingForConfirmation)
            case (_, .idling):
                throw UnexpectedResponse(kind: .idleRunning)
            }
        }

        mutating func receiveContinuationRequest(_: ContinuationRequest) throws {
            switch self.state {
            case .waitingForConfirmation:
                self.state = .idling
            case .idling:
                throw UnexpectedContinuationRequest(kind: .idle)
            }
        }
    }
}
