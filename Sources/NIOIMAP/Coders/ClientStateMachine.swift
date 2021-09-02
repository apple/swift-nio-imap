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
        
        /// We're expecting either a tagged or untagged response
        case expectingNormalResponse
        
        /// We're in some part of the idle flow
        case idle(ClientStateMachine.Idle)
        
        /// We're in some part of the authentication flow
        case authenticating(ClientStateMachine.Authentication)
        
        /// We're in some part of the appending flow
        case appending(ClientStateMachine.Append)
        
        /// We've sent a command that requires a continuation request
        /// for example `A1 LOGIN {1}\r\n\\ {1}\r\n\\`, and
        /// we're waiting for the continuation request from the server
        /// before sending another chunk.
        case expectingLiteralContinuationRequest
        
        /// An error has occurred and the connection should
        /// now be closed.
        case error
    }

    /// Capabilites are sent by an IMAP server. Once the desired capabilities have been
    /// select from the server's response, update these encoding options to enable or disable
    /// certain types of literal encodings.
    /// - Note: Make sure to send `.enable` commands for applicable capabilities
    /// - Important: Modifying this value is not thread-safe
    var encodingOptions: CommandEncodingOptions

    // We won't always have an active encode buffer, but anytime we go to use one it
    // should exist, so IUO is fine IMHO.
    private var activeEncodeBuffer: CommandEncodeBuffer!
    private var activeWritePromise: EventLoopPromise<Void>?
    private var state: State = .expectingNormalResponse
    private var activeCommandTags: Set<String> = []

    // This pattern is used to provide a bit of extra security around the allocator
    // As the state machine will likely exist before we are able to get an allocator
    // from the channel.
    private var _allocator: ByteBufferAllocator!
    var allocator: ByteBufferAllocator {
        set {
            self._allocator = newValue
        }
        get {
            assert(self._allocator != nil, "Always set the allocator before trying to access it")
            return self._allocator
        }
    }

    // We mark where we should write up to at the next oppurtunity
    // using the `flush` method called from the channel handler.
    private var queuedCommands: MarkedCircularBuffer<(CommandStreamPart, EventLoopPromise<Void>?)> = .init(initialCapacity: 16)

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

    /// Tells the state machine that a continuation request has been received from the network.
    /// Returns the next batch of chunks to write.
    mutating func receiveContinuationRequest(_ req: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        do {
            return try self._receiveContinuationRequest(req)
        } catch {
            self.state = .error
            throw error
        }
    }
    
    private mutating func _receiveContinuationRequest(_ req: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .appending(let stateMachine):
            return try self.receiveContinuationRequest_appending(stateMachine: stateMachine, request: req)
        case .expectingLiteralContinuationRequest:
            return try self.receiveContinuationRequest_expectingLiteralContinuationRequest(request: req)
        case .authenticating(let stateMachine):
            return try self.receiveContinuationRequest_authenticating(stateMachine: stateMachine, request: req)
        case .idle(let stateMachine):
            return try self.receiveContinuationRequest_idle(stateMachine: stateMachine, request: req)
        case .expectingNormalResponse, .error:
            throw UnexpectedContinuationRequest()
        }
    }

    /// Tells the state machine that some response has been received. Note that receiving a response
    /// will never result in the client having to perform some action.
    mutating func receiveResponse(_ response: Response) throws {
        do {
            return try self._receiveResponse(response)
        } catch {
            self.state = .error
            throw error
        }
    }
    
    mutating func _receiveResponse(_ response: Response) throws {
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

    /// Tells the state machine that the client woulud like to send a command.
    /// We then return any chunks that can be written.
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

    /// Mark the back of the current command queue, and write up to and including
    /// this point next time we receive a continuation request or send a command.
    /// Note that we might not actually reach the mark as we may encounter a command
    /// that requires a continuation request.
    mutating func flush() {
        self.queuedCommands.mark()
    }
}

// MARK: - Receive

extension ClientStateMachine {
    private mutating func receiveContinuationRequest_appending(stateMachine: Append, request: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard case .appending = self.state else {
            assert(false, "Invalid state")
        }

        var stateMachine = stateMachine
        self.state = try stateMachine.receiveContinuationRequest(request)
        self.activeEncodeBuffer = nil
        self.activeWritePromise = nil
        if let (command, promise) = self.queuedCommands.popFirst() {
            var encodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
            encodeBuffer.writeCommandStream(command)
            self.activeEncodeBuffer = encodeBuffer
            self.activeWritePromise = promise
        }
        return try self.extractSendableChunks()
    }

    private mutating func receiveContinuationRequest_expectingLiteralContinuationRequest(request: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingNormalResponse, .idle, .authenticating, .appending, .error:
            throw UnexpectedContinuationRequest()
        case .expectingLiteralContinuationRequest:
            break
        }

        self.state = .expectingNormalResponse
        let result = try self.extractSendableChunks()

        // safe to bang as if we've successfully received a continuation request then there
        // MUST be something to send
        if result.last!.0.waitForContinuation { // we've found a continuation
            self.state = .expectingLiteralContinuationRequest
        } else {
            self.activeWritePromise = nil
            self.activeEncodeBuffer = nil
            self.state = .expectingNormalResponse
        }
        return result
    }

    private mutating func receiveContinuationRequest_authenticating(stateMachine: Authentication, request: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard case .authenticating = self.state else {
            assert(false, "Invalid state")
        }

        var stateMachine = stateMachine
        switch request {
        case .responseText:
            // no valid base 64, so we can assume it was empty
            self.state = try stateMachine.receiveResponse(.authenticationChallenge(self.makeNewBuffer()))
        case .data(let byteBuffer):
            self.state = try stateMachine.receiveResponse(.authenticationChallenge(byteBuffer))
        }
        return []
    }

    private mutating func receiveContinuationRequest_idle(stateMachine: Idle, request: ContinuationRequest) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard case .idle = self.state else {
            assert(false, "Invalid state")
        }

        var stateMachine = stateMachine
        // A continuation when in idle state means it's been confirmed
        self.state = try stateMachine.receiveResponse(.idleStarted)
        return []
    }
}

// MARK: - Send

extension ClientStateMachine {
    private mutating func sendCommand_state_normalResponse(command: CommandStreamPart) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingLiteralContinuationRequest, .idle, .authenticating, .appending, .error:
            throw UnexpectedContinuationRequest()
        case .expectingNormalResponse:
            break
        }

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
        switch self.state {
        case .expectingLiteralContinuationRequest, .idle, .authenticating, .appending, .error:
            throw UnexpectedContinuationRequest()
        case .expectingNormalResponse:
            break
        }

        // update the state
        let chunk = self.activeEncodeBuffer.buffer.nextChunk()
        switch command.command {
        case .idleStart:
            try self.guardAgainstMultipleRunningCommands(.tagged(command))
            self.state = .idle(Idle())
        case .authenticate:
            try self.guardAgainstMultipleRunningCommands(.tagged(command))
            self.state = .authenticating(Authentication())
        default:
            if chunk.waitForContinuation {
                self.state = .expectingLiteralContinuationRequest
                return [(chunk, self.activeWritePromise)] // nil promise because the command required continuation
            }
        }

        let promise = self.activeWritePromise
        self.activeEncodeBuffer = nil
        self.activeWritePromise = nil
        return [(chunk, promise)]
    }

    private mutating func sendAppendCommand(_ command: AppendCommand) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingLiteralContinuationRequest, .idle, .authenticating, .appending, .error:
            throw UnexpectedContinuationRequest()
        case .expectingNormalResponse:
            break
        }

        // no other commands can be running when we start appending
        try self.guardAgainstMultipleRunningCommands(.append(command))
        self.state = .appending(Append())

        // TODO: This assumes that the append command doesn't require a continuation - fix this in another PR
        // Only send bytes if there isn't a command ahead in the queue
        defer {
            self.activeEncodeBuffer = nil
            self.activeWritePromise = nil
        }
        return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
    }

    /// Iterate through the current command queue until we reached the marked position
    /// or encounter a command that requires a continuation request to complete.
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

    /// Throws an error if more than one command is runnning, otherwise does nothing
    private func guardAgainstMultipleRunningCommands(_ command: CommandStreamPart) throws {
        guard self.activeCommandTags.count == 1 else {
            throw InvalidCommandForState(command)
        }
    }

    private func makeNewBuffer() -> ByteBuffer {
        self.allocator.buffer(capacity: 128)
    }

    private mutating func sendNextCommand() throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        assert(self.queuedCommands.count > 0)

        guard self.activeEncodeBuffer == nil else {
            return []
        }

        let (command, promise) = self.queuedCommands.popFirst()! // we've asserted there's at least one
        switch self.state {
        case .expectingNormalResponse:
            return try self.sendNextCommand_expectingNormalResponse(command: command, promise: promise)
        case .idle(let idleStateMachine):
            return try self.sendNextCommand_idle(command: command, promise: promise, idleStateMachine: idleStateMachine)
        case .authenticating(let authStateMachine):
            return try self.sendNextCommand_authenticating(command: command, promise: promise, authenticationStateMachine: authStateMachine)
        case .appending(let appendingStateMachine):
            return try self.sendNextCommand_appending(command: command, promise: promise, appendingStateMachine: appendingStateMachine)
        case .error:
            throw InvalidCommandForState(command)
        case .expectingLiteralContinuationRequest:
            return try self.sendNextCommand_expectingLiteralContinuationRequest()
        }
    }
    
    /// If we're "expecting a normal response" then we aren't waiting for a continuation request. However, the
    /// command we want to send may require a continuation itself. We begin by writing the command to
    /// an encode buffer to isolate any required continuations, and then send every chunk until we run out of chunks
    /// to send, or we find a chunk that requires a continuation request.
    private mutating func sendNextCommand_expectingNormalResponse(command: CommandStreamPart, promise: EventLoopPromise<Void>?) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .idle, .authenticating, .appending, .expectingLiteralContinuationRequest, .error:
            throw InvalidCommandForState(command)
        case .expectingNormalResponse:
            break
        }
        
        self.activeWritePromise = promise
        self.activeEncodeBuffer = .init(buffer: self.makeNewBuffer(), options: self.encodingOptions)
        self.activeEncodeBuffer.writeCommandStream(command)
        return try self.sendCommand_state_normalResponse(command: command)
    }
    
    /// When idle we need to first defer to the idle state machine to make sure we can send the
    /// the next part of the authentication. If we can, then just send the message. There's no need
    /// to wait for a continuation request.
    private mutating func sendNextCommand_idle(command: CommandStreamPart, promise: EventLoopPromise<Void>?, idleStateMachine: Idle) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingNormalResponse, .authenticating, .appending, .expectingLiteralContinuationRequest, .error:
            throw InvalidCommandForState(command)
        case .idle:
            break
        }
        
        var idleStateMachine = idleStateMachine
        self.state = try idleStateMachine.sendCommand(command)
        self.activeWritePromise = nil
        self.activeEncodeBuffer = nil
        var encodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
        encodeBuffer.writeCommandStream(command)
        return [(encodeBuffer.buffer.nextChunk(), promise)]
    }
    
    /// When authenticating we need to first defer to the authentication state machine to make sure
    /// can send the next part of the authentication. If we can, then just send the message. There's
    /// no need to wait for a continuation request.
    private mutating func sendNextCommand_authenticating(command: CommandStreamPart, promise: EventLoopPromise<Void>?, authenticationStateMachine: Authentication) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingNormalResponse, .idle, .appending, .expectingLiteralContinuationRequest, .error:
            throw InvalidCommandForState(command)
        case .authenticating:
            break
        }
        
        var authStateMachine = authenticationStateMachine
        self.state = try authStateMachine.sendCommand(command)
        self.activeWritePromise = nil
        self.activeEncodeBuffer = nil
        var encodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
        encodeBuffer.writeCommandStream(command)
        return [(encodeBuffer.buffer.nextChunk(), promise)]
    }
    
    /// When appending we need to first defer to the appending state machine to see if we can actually
    /// a command given our current state. If we can then we need to check what kind of command is
    /// being sent. If we're beginning an append or catenation then we need to wait for a continuation
    /// request, otherwise we can send the command and continue.
    private mutating func sendNextCommand_appending(command: CommandStreamPart, promise: EventLoopPromise<Void>?, appendingStateMachine: Append) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingNormalResponse, .idle, .authenticating, .expectingLiteralContinuationRequest, .error:
            throw InvalidCommandForState(command)
        case .appending:
            break
        }
     
        var appendingStateMachine = appendingStateMachine
        self.state = try appendingStateMachine.sendCommand(command)
        
        switch command {
            
        case .append(.beginMessage), .append(.catenateData):
            self.activeWritePromise = promise
            self.activeEncodeBuffer = .init(buffer: self.makeNewBuffer(), options: self.encodingOptions)
            self.activeEncodeBuffer.writeCommandStream(command)
            return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
            
        default:
            self.activeWritePromise = nil
            self.activeEncodeBuffer = nil
            var encodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
            encodeBuffer.writeCommandStream(command)
            return [(encodeBuffer.buffer.nextChunk(), promise)]
        }
    }
    
    /// If we're currently waiting for a continuation request then we can't send a command, so return nothing.
    private mutating func sendNextCommand_expectingLiteralContinuationRequest() throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        return []
    }
}
