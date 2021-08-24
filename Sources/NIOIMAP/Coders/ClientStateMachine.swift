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

public struct UnexpectedChunk: Error {
    public init() {}
}

public struct UnexpectedContinuationRequest: Error {
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

struct ClientStateMachine {
    enum State: Hashable {
        case expectingNormalResponse
        case idle(ClientStateMachine.Idle)
        case authenticating(ClientStateMachine.Authentication)
        case appending(ClientStateMachine.Append)
        case expectingLiteralContinuationRequest
        case error
    }

    private var activeEncodeBuffer: CommandEncodeBuffer!
    private var activeWritePromise: EventLoopPromise<Void>?
    private var queuedCommands: MarkedCircularBuffer<(CommandStreamPart, EventLoopPromise<Void>?)> = .init(initialCapacity: 16)
    private var state: State = .expectingNormalResponse
    private var activeCommandTags: Set<String> = []

    mutating func receiveContinuationRequest(_ req: ContinuationRequest) throws -> [(ByteBuffer, EventLoopPromise<Void>?)] {
        switch self.state {
        case .appending(var appendStateMachine):
            self.state = try appendStateMachine.receiveContinuationRequest(req)

            return self.extractSendableChunks().map { ($0.0, $0.1) }
        case .expectingLiteralContinuationRequest:
            let result = self.extractSendableChunks()
            if result.last!.2 { // we've found a continuation
                self.state = .expectingLiteralContinuationRequest
            } else {
                self.state = .expectingNormalResponse
            }
            return result.map { ($0.0, $0.1) }
        case .authenticating(var authenticateStateMachine):
            switch req {
            case .responseText:
                throw UnexpectedContinuationRequest()
            case .data(let byteBuffer):
                self.state = try authenticateStateMachine.receiveResponse(.authenticationChallenge(byteBuffer))
                return []
            }
        case .expectingNormalResponse, .idle, .error:
            throw UnexpectedContinuationRequest()
        }
    }

    mutating func receiveResponse(_ response: Response) throws {
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
        case .expectingNormalResponse:
            break
        case .expectingLiteralContinuationRequest, .error:
            throw UnexpectedResponse()
        }
    }

    mutating func sendCommand(_ command: CommandStreamPart, promise: EventLoopPromise<Void>? = nil) throws -> [(ByteBuffer, EventLoopPromise<Void>?)] {
        if let tag = command.tag {
            let (inserted, _) = self.activeCommandTags.insert(tag)
            guard inserted else {
                throw DuplicateCommandTag(tag: tag)
            }
        }
        self.queuedCommands.append((command, promise))
        return try self.sendNextCommand()
    }
    
    private mutating func sendNextCommand() throws -> [(ByteBuffer, EventLoopPromise<Void>?)]{
        assert(self.queuedCommands.count > 0)
        
        let (command, promise) = self.queuedCommands.first! // we've asserted there's at least one
        
        switch self.state {
        case .expectingNormalResponse:
            guard self.activeEncodeBuffer == nil else {
                return []
            }
            _ = self.queuedCommands.popFirst()! // we've asserted there's at least one
            self.activeWritePromise = promise
            self.activeEncodeBuffer = .init(buffer: ByteBuffer(), options: .rfc3501)
            self.activeEncodeBuffer.writeCommandStream(command)
            return try self.sendCommand_state_normalResponse(command: command, promise: promise)
        case .idle(var idleStateMachine):
            _ = self.queuedCommands.popFirst()!
            self.state = try idleStateMachine.sendCommand(command)
        case .authenticating(var authStateMachine):
            _ = self.queuedCommands.popFirst()!
            self.state = try authStateMachine.sendCommand(command)
        case .appending(var appendingStateMachine):
            _ = self.queuedCommands.popFirst()!
            self.state = try appendingStateMachine.sendCommand(command)
        case .error:
            throw InvalidCommandForState(command)
        case .expectingLiteralContinuationRequest:
            break
        }
        return []
    }
}

// MARK: - Send

extension ClientStateMachine {
    private mutating func sendCommand_state_normalResponse(command: CommandStreamPart, promise: EventLoopPromise<Void>?) throws -> [(ByteBuffer, EventLoopPromise<Void>?)] {
        assert(self.state == .expectingNormalResponse)

        switch command {
        case .idleDone, .continuationResponse:
            throw InvalidCommandForState(command)
        case .tagged(let tc):
            return try self.sendTaggedCommand(tc, promise: promise)
        case .append(let ac):
            return try self.sendAppendCommand(ac, promise: promise)
        }
    }

    private mutating func sendTaggedCommand(_ command: TaggedCommand, promise: EventLoopPromise<Void>?) throws -> [(ByteBuffer, EventLoopPromise<Void>?)] {
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
            
            let buffer = self.activeEncodeBuffer.buffer.nextChunk().bytes
            self.activeEncodeBuffer = nil
            self.activeWritePromise = nil
            return [(buffer, promise)]
            
        case .authenticate:

            // no other commands can be running when we start authenticating
            guard self.activeCommandTags.count == 1 else {
                throw InvalidCommandForState(.tagged(command))
            }
            self.state = .authenticating(Authentication())
            
            // The AUTHENTICATE command will never have a continuation
            let buffer = self.activeEncodeBuffer.buffer.nextChunk().bytes
            self.activeEncodeBuffer = nil
            self.activeWritePromise = nil
            return [(buffer, promise)]
            
        default:
            let chunk = self.activeEncodeBuffer.buffer.nextChunk()
            if chunk.waitForContinuation {
                self.state = .expectingLiteralContinuationRequest
                return [(chunk.bytes, nil)] // nil promise because the command required continuation
            } else {
                self.activeWritePromise = nil
                self.activeEncodeBuffer = nil
                self.state = .expectingNormalResponse
                assert(!chunk.waitForContinuation)
                return [(chunk.bytes, promise)] // there'll only ever be one chunk here
            }
        }
    }

    private mutating func sendAppendCommand(_ command: AppendCommand, promise: EventLoopPromise<Void>?) throws -> [(ByteBuffer, EventLoopPromise<Void>?)] {
        assert(self.state == .expectingNormalResponse)

        // no other commands can be running when we start appending
        guard self.activeCommandTags.count == 1 else {
            throw InvalidCommandForState(.append(command))
        }
        self.state = .appending(Append())
        
        // TODO: This assumes that the append command doesn't require a continuation - fix this in another PR
        // Only send bytes if there isn't a command ahead in the queue
        return [(self.activeEncodeBuffer.buffer.nextChunk().bytes, promise)]
    }
    
    private mutating func extractSendableChunks() -> [(ByteBuffer, EventLoopPromise<Void>?, Bool)] {
        var result: [(ByteBuffer, EventLoopPromise<Void>?, Bool)] = []
        
        while self.activeEncodeBuffer != nil {
            let chunk = self.activeEncodeBuffer.buffer.nextChunk()
            if chunk.waitForContinuation {
                result.append((chunk.bytes, nil, true))
                break
            } else {
                self.activeEncodeBuffer = nil
                self.activeWritePromise = nil
                result.append((chunk.bytes, self.activeWritePromise, false))
                
                guard let (command, promise) = self.queuedCommands.popFirst() else {
                    continue
                }
                
                // TODO: Load capabilities from somewhere
                self.activeWritePromise = promise
                self.activeEncodeBuffer = .init(buffer: ByteBuffer(), options: .rfc3501)
                self.activeEncodeBuffer.writeCommandStream(command)
            }
        }
        
        
        return result
    }
    
    public mutating func flush() {
        self.queuedCommands.mark()
    }
}
