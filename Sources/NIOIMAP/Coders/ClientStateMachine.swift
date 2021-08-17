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
@_spi(NIOIMAPInternal) import NIOIMAPCore

public struct InvalidClientState: Error {
    public init() {}
}

public struct UnexpectedResponse: Error {
    public init() {}
}

public struct DuplicateCommandTag: Error {
    public var tag: String

    public init(tag: String) {
        self.tag = tag
    }
}

public struct InvalidCommandForState: Error, Equatable {
    public var command: CommandStreamPart

    public init(_ command: CommandStreamPart) {
        self.command = command
    }
}

struct ClientStateMachine: Hashable {
    enum State: Hashable {
        case expectingNormalResponse
        case idle(ClientStateMachine.Idle)
        case authenticating(ClientStateMachine.Authentication)
        case appending(ClientStateMachine.Append)
        case expectingLiteralContinuationRequest(CommandEncodeBuffer)
        case error
    }

    private var state: State = .expectingNormalResponse
    private(set) var activeCommandTags: Set<String> = []

    mutating func receiveContinuationRequest(_ req: ContinuationRequest) throws {
        switch self.state {
        case .appending(var appendStateMachine):
            self.state = try appendStateMachine.receiveContinuationRequest(req)
        default:
            fatalError("TODO")
        }
    }

    mutating func receiveResponse(_ response: Response) throws -> EncodeBuffer.Chunk? {
        if let tag = response.tag {
            guard self.activeCommandTags.remove(tag) != nil else {
                throw UnexpectedResponse()
            }
        }

        switch self.state {
        case .idle(var idleStateMachine):
            self.state = try idleStateMachine.receiveResponse(response)
        case .authenticating(var authStateMachine):
            self.state = try authStateMachine.receiveResponse(response)
        case .appending(var appendStateMachine):
            self.state = try appendStateMachine.receiveResponse(response)
        default:
            self.state = .expectingNormalResponse
        }
        
        return nil
    }

    mutating func sendCommand(_ command: CommandStreamPart) throws -> EncodeBuffer.Chunk {
        if let tag = command.tag {
            let (inserted, _) = self.activeCommandTags.insert(tag)
            guard inserted else {
                throw DuplicateCommandTag(tag: tag)
            }
        }
        
        // TODO: Pull in the capabilities from somewhere
        var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .init())
        encodeBuffer.writeCommandStream(command)
        let chunk = encodeBuffer.buffer.nextChunk()

        switch self.state {
        case .expectingNormalResponse:
            try self.sendCommand_state_normalResponse(command: command)
            if chunk.waitForContinuation {
                self.state = .completingCommand(encodeBuffer)
                return chunk
            } else {
                self.state = .expectingNormalResponse
                return chunk
            }
        case .idle(var idleStateMachine):
            self.state = try idleStateMachine.sendCommand(command)
            return chunk // can only be one chunk here
        case .authenticating(var authStateMachine):
            self.state = try authStateMachine.sendCommand(command)
            return chunk // can only be one chunk here
        case .appending(var appendingStateMachine):
            self.state = try appendingStateMachine.sendCommand(command)
            return chunk // can only be one chunk here
        case .completingCommand:
            throw InvalidCommandForState(command)
        default:
            fatalError("TODO")
        }
    }
    
    mutating func sendChunk(_ chunk : EncodeBuffer.Chunk) throws {
        switch self.state {
        case .expectingNormalResponse, .error, .idle, .authenticating, .appending, .expectingLiteralContinuationRequest:
            fatalError("Test")
        case .completingCommand:
            break
        }
    }
}

// MARK: - Send

extension ClientStateMachine {
    private mutating func sendCommand_state_normalResponse(command: CommandStreamPart) throws {
        assert(self.state == .expectingNormalResponse)

        switch command {
        case .idleDone, .continuationResponse:
            throw InvalidCommandForState(command)
        case .tagged(let tc):
            try self.sendTaggedCommand(tc)
        case .append(let ac):
            try self.sendAppendCommand(ac)
        }
    }

    private mutating func sendTaggedCommand(_ command: TaggedCommand) throws {
        assert(self.state == .expectingNormalResponse)

        // it's not practical to switch over
        // every command here, there are over
        // 50 of them...
        switch command.command {
        case .idleStart:

            // no other commands can be running when we start idling
            guard self.activeCommandTags.count == 1 else {
                throw InvalidCommandForState(.tagged(command))
            }
            self.state = .idle(Idle())
        case .authenticate:

            // no other commands can be running when we start authenticating
            guard self.activeCommandTags.count == 1 else {
                throw InvalidCommandForState(.tagged(command))
            }
            self.state = .authenticating(Authentication())
        default:
            break
        }
    }

    private mutating func sendAppendCommand(_ command: AppendCommand) throws {
        assert(self.state == .expectingNormalResponse)

        // no other commands can be running when we start appending
        guard self.activeCommandTags.count == 1 else {
            throw InvalidCommandForState(.append(command))
        }
        self.state = .appending(Append())
    }
}
