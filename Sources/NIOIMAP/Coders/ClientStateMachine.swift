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

    /// Capabilites are sent by an IMAP server. Once the desired capabilities have been
    /// select from the server's response, update these encoding options to enable or disable
    /// certain types of literal encodings.
    /// - Note: Make sure to send `.enable` commands for applicable capabilities
    /// - Important: Modifying this value is not thread-safe
    var encodingOptions: CommandEncodingOptions

    private var activeEncodeBuffer: CommandEncodeBuffer!
    private var activeWritePromise: EventLoopPromise<Void>?
    private var queuedCommands: MarkedCircularBuffer<(CommandStreamPart, EventLoopPromise<Void>?)> = .init(initialCapacity: 16)
    private var state: State = .expectingNormalResponse
    private var activeCommandTags: Set<String> = []

    var authenticating: Bool {
        switch self.state {
        case .authenticating:
            return true
        case .expectingNormalResponse, .expectingLiteralContinuationRequest, .appending, .error, .idle:
            return false
        }
    }

    var idling: Bool {
        switch self.state {
        case .idle:
            return true
        case .expectingNormalResponse, .expectingLiteralContinuationRequest, .appending, .error, .authenticating:
            return false
        }
    }

    init(encodingOptions: CommandEncodingOptions) {
        self.encodingOptions = encodingOptions
    }

    mutating func receiveContinuationRequest(_ req: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .appending(var appendStateMachine):
            self.state = try appendStateMachine.receiveContinuationRequest(req)
            self.activeEncodeBuffer = nil
            self.activeWritePromise = nil
            if let (command, promise) = self.queuedCommands.popFirst() {
                var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: self.encodingOptions)
                encodeBuffer.writeCommandStream(command)
                self.activeEncodeBuffer = encodeBuffer
                self.activeWritePromise = promise
            }
            return try self.extractSendableChunks()
        case .expectingLiteralContinuationRequest:
            self.state = .expectingNormalResponse
            let result = try self.extractSendableChunks()
            if result.last!.0.waitForContinuation { // we've found a continuation
                self.state = .expectingLiteralContinuationRequest
            } else {
                self.activeWritePromise = nil
                self.activeEncodeBuffer = nil
                self.state = .expectingNormalResponse
            }
            return result
        case .authenticating(var authenticateStateMachine):
            switch req {
            case .responseText:
                // no valid base 64, so we can assume it was empty
                self.state = try authenticateStateMachine.receiveResponse(.authenticationChallenge(ByteBuffer()))
            case .data(let byteBuffer):
                self.state = try authenticateStateMachine.receiveResponse(.authenticationChallenge(byteBuffer))
            }
            return []
        case .idle(var idleStateMachine):
            // A continuation when in idle state means it's been confirmed
            self.state = try idleStateMachine.receiveResponse(.idleStarted)
            return []
        case .expectingNormalResponse, .error:
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

    mutating func sendCommand(_ command: CommandStreamPart, promise: EventLoopPromise<Void>? = nil) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        if let tag = command.tag {
            let (inserted, _) = self.activeCommandTags.insert(tag)
            guard inserted else {
                throw DuplicateCommandTag(tag: tag)
            }
        }
        self.queuedCommands.append((command, promise))
        do {
            return try self.sendNextCommand()
        } catch {
            self.state = .error
            throw error
        }
    }

    private mutating func sendNextCommand() throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        assert(self.queuedCommands.count > 0)

        guard self.activeEncodeBuffer == nil else {
            return []
        }

        let (command, promise) = self.queuedCommands.popFirst()! // we've asserted there's at least one

        switch self.state {
        case .expectingNormalResponse:
            self.activeWritePromise = promise
            self.activeEncodeBuffer = .init(buffer: ByteBuffer(), options: self.encodingOptions)
            self.activeEncodeBuffer.writeCommandStream(command)
            return try self.sendCommand_state_normalResponse(command: command)
        case .idle(var idleStateMachine):
            self.state = try idleStateMachine.sendCommand(command)
        case .authenticating(var authStateMachine):
            self.state = try authStateMachine.sendCommand(command)
        case .appending(var appendingStateMachine):
            self.state = try appendingStateMachine.sendCommand(command)
            switch command {
            case .append(.beginMessage), .append(.catenateData):
                self.activeWritePromise = promise
                self.activeEncodeBuffer = .init(buffer: ByteBuffer(), options: self.encodingOptions)
                self.activeEncodeBuffer.writeCommandStream(command)
                return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
            default:
                defer {
                    self.activeWritePromise = nil
                    self.activeEncodeBuffer = nil
                }
                self.activeWritePromise = promise
                self.activeEncodeBuffer = .init(buffer: ByteBuffer(), options: self.encodingOptions)
                self.activeEncodeBuffer.writeCommandStream(command)
                return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
            }
        case .error:
            throw InvalidCommandForState(command)
        case .expectingLiteralContinuationRequest:
            return []
        }

        self.activeWritePromise = promise
        self.activeEncodeBuffer = .init(buffer: ByteBuffer(), options: self.encodingOptions)
        self.activeEncodeBuffer.writeCommandStream(command)
        defer {
            self.activeWritePromise = nil
            self.activeEncodeBuffer = nil
        }
        return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
    }
}

// MARK: - Send

extension ClientStateMachine {
    private mutating func sendCommand_state_normalResponse(command: CommandStreamPart) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        assert(self.state == .expectingNormalResponse)

        switch command {
        case .idleDone, .continuationResponse:
            throw InvalidCommandForState(command)
        case .tagged(let tc):
            return try self.sendTaggedCommand(tc)
        case .append(let ac):
            return try self.sendAppendCommand(ac)
        }
    }

    private mutating func sendTaggedCommand(_ command: TaggedCommand) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
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

            defer {
                self.activeEncodeBuffer = nil
                self.activeWritePromise = nil
            }

            let chunk = self.activeEncodeBuffer.buffer.nextChunk()
            return [(chunk, self.activeWritePromise)]

        case .authenticate:

            // no other commands can be running when we start authenticating
            guard self.activeCommandTags.count == 1 else {
                throw InvalidCommandForState(.tagged(command))
            }
            self.state = .authenticating(Authentication())

            // The AUTHENTICATE command will never have a continuation
            let chunk = self.activeEncodeBuffer.buffer.nextChunk()
            defer {
                self.activeEncodeBuffer = nil
                self.activeWritePromise = nil
            }
            return [(chunk, self.activeWritePromise)]

        default:
            let chunk = self.activeEncodeBuffer.buffer.nextChunk()
            if chunk.waitForContinuation {
                self.state = .expectingLiteralContinuationRequest
                return [(chunk, self.activeWritePromise)] // nil promise because the command required continuation
            } else {
                defer {
                    self.activeEncodeBuffer = nil
                    self.activeWritePromise = nil
                }
                self.state = .expectingNormalResponse
                assert(!chunk.waitForContinuation)
                return [(chunk, self.activeWritePromise)] // there'll only ever be one chunk here
            }
        }
    }

    private mutating func sendAppendCommand(_ command: AppendCommand) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        assert(self.state == .expectingNormalResponse)

        // no other commands can be running when we start appending
        guard self.activeCommandTags.count == 1 else {
            throw InvalidCommandForState(.append(command))
        }
        self.state = .appending(Append())

        // TODO: This assumes that the append command doesn't require a continuation - fix this in another PR
        // Only send bytes if there isn't a command ahead in the queue
        defer {
            self.activeEncodeBuffer = nil
            self.activeWritePromise = nil
        }
        return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
    }

    private mutating func extractSendableChunks() throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard self.activeEncodeBuffer != nil else {
            return []
        }

        let chunk = self.activeEncodeBuffer.buffer.nextChunk()
        if chunk.waitForContinuation {
            return [(chunk, self.activeWritePromise)]
        } else {
            var result: [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] = []
            result.append((chunk, self.activeWritePromise))
            while self.queuedCommands.hasMark, !result.last!.0.waitForContinuation {
                self.activeEncodeBuffer = nil
                self.activeWritePromise = nil
                for val in try self.sendNextCommand() {
                    result.append(val)
                }
            }
            return result
        }
    }

    public mutating func flush() {
        self.queuedCommands.mark()
    }
}
