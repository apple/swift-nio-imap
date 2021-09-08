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

// TODO: See note below.
// This state machine could potentially be improved by
// splitting into 2. One that manages command logic
// (can this command be sent), and one that handles
// continuation logic once a command has been given the
// ok.
struct ClientStateMachine {
    enum ContinuationRequestAction: Equatable {
        case sendChunks([(EncodeBuffer.Chunk, EventLoopPromise<Void>?)])
        case fireIdleStarted
        case fireAuthenticationChallenge

        static func == (lhs: ClientStateMachine.ContinuationRequestAction, rhs: ClientStateMachine.ContinuationRequestAction) -> Bool {
            switch (lhs, rhs) {
            case (.sendChunks(let c1), .sendChunks(let c2)):
                return c1.elementsEqual(c2, by: { $0.0 == $1.0 && $0.1?.futureResult === $1.1?.futureResult })
            case (.fireIdleStarted, .fireIdleStarted):
                return true
            case (.fireAuthenticationChallenge, .fireAuthenticationChallenge):
                return true
            default:
                return false
            }
        }
    }

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
    var encodingOptions: CommandEncodingOptions

    // We won't always have an active encode buffer, but anytime we go to use one it
    // should exist, so IUO is fine IMHO.
    private var activeEncodeBuffer: CommandEncodeBuffer!
    private var activeWritePromise: EventLoopPromise<Void>?
    private var state: State = .expectingNormalResponse
    private var activeCommandTags: Set<String> = []

    /// This pattern is used to provide a bit of extra security around the allocator
    /// As the state machine will likely exist before we are able to get an allocator
    /// from the channel. We have to use an IUO because the state machine is likely to
    /// be created before it's added to a channel, so we have no way of getting the
    /// allocator. Make sure to set the allocator as soon as possible.
    var allocator: ByteBufferAllocator!

    // We mark where we should write up to at the next opportunity
    // using the `flush` method called from the channel handler.
    private var queuedCommands: MarkedCircularBuffer<(CommandStreamPart, EventLoopPromise<Void>?)> = .init(initialCapacity: 16)

    init(encodingOptions: CommandEncodingOptions) {
        self.encodingOptions = encodingOptions
    }

    /// Tells the state machine that a continuation request has been received from the network.
    /// Returns the next batch of chunks to write.
    mutating func receiveContinuationRequest(_ req: ContinuationRequest) throws -> ContinuationRequestAction {
        do {
            return try self._receiveContinuationRequest(req)
        } catch {
            self.state = .error
            throw error
        }
    }

    private mutating func _receiveContinuationRequest(_ req: ContinuationRequest) throws -> ContinuationRequestAction {
        switch self.state {
        case .appending:
            return try self.receiveContinuationRequest_appending(request: req)
        case .expectingLiteralContinuationRequest:
            return try self.receiveContinuationRequest_expectingLiteralContinuationRequest(request: req)
        case .authenticating:
            return try self.receiveContinuationRequest_authenticating(request: req)
        case .idle:
            return try self.receiveContinuationRequest_idle(request: req)
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
            try idleStateMachine.receiveResponse(response)
            self.state = .idle(idleStateMachine)
        case .authenticating(var authStateMachine):
            if try authStateMachine.receiveResponse(response) {
                self.state = .expectingNormalResponse
            } else {
                self.state = .authenticating(authStateMachine)
            }
        case .appending(var appendStateMachine):
            if try appendStateMachine.receiveResponse(response) {
                self.state = .expectingNormalResponse
            } else {
                self.state = .appending(appendStateMachine)
            }
        case .expectingLiteralContinuationRequest, .error:
            throw UnexpectedResponse()

        case .expectingNormalResponse:
            switch response {
            case .untagged, .fetch, .tagged:
                // we expected a normal response and receievd a normal
                // response, nothing to see here
                break
            case .fatal:
                // if the server has sent a fatal then we shouldn't be able to do anything else
                self.state = .error
            case .authenticationChallenge, .idleStarted:
                // we should be in a substate to be receiving these responses
                throw UnexpectedResponse()
            }
        }
    }

    /// Tells the state machine that the client would like to send a command.
    /// We then return any chunks that can be written.
    mutating func sendCommand(_ command: CommandStreamPart, promise: EventLoopPromise<Void>? = nil) throws -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        if let tag = command.tag {
            let (inserted, _) = self.activeCommandTags.insert(tag)
            guard inserted else {
                throw DuplicateCommandTag(tag: tag)
            }
        }
        self.queuedCommands.append((command, promise))
        return self.sendNextCommand()
    }

    /// Mark the back of the current command queue, and write up to and including
    /// this point next time we receive a continuation request or send a command.
    /// Note that we might not actually reach the mark as we may encounter a command
    /// that requires a continuation request.
    mutating func flush() {
        self.queuedCommands.mark()
    }

    /// Returns all of the promises for the writes that have not yet completed.
    /// These should probably be failed.
    mutating func channelInactive() -> [EventLoopPromise<Void>] {
        // we don't care what state we were in, all we want is
        // to move to the error state so that nothing else is sent
        self.state = .error

        var promises: [EventLoopPromise<Void>] = []
        if let current = self.activeWritePromise {
            self.activeWritePromise = nil
            promises.append(current)
        }

        promises.append(contentsOf: self.queuedCommands.compactMap(\.1))
        return promises
    }
}

// MARK: - Receive

extension ClientStateMachine {
    private mutating func receiveContinuationRequest_appending(request: ContinuationRequest) throws -> ContinuationRequestAction {
        guard case .appending(var appendingStateMachine) = self.state else {
            throw UnexpectedContinuationRequest()
        }

        try appendingStateMachine.receiveContinuationRequest(request)
        self.state = .appending(appendingStateMachine)

        // We need to get the client handler to fullfil the existing promise, but the bytes
        // will have already been written to the network. The `nextChunk` here will always be
        // empty.
        let nextBuffer = self.activeEncodeBuffer.buffer.nextChunk()
        precondition(nextBuffer.bytes.readableBytes == 0 && !nextBuffer.waitForContinuation)
        var results = [(nextBuffer, self.activeWritePromise)]
        self.activeEncodeBuffer = nil
        self.activeWritePromise = nil

        if let (command, promise) = self.queuedCommands.popFirst() {
            self.activeEncodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
            self.activeEncodeBuffer.writeCommandStream(command)
            self.activeWritePromise = promise
            results.append(contentsOf: self.extractSendableChunks())
        }

        return .sendChunks(results)
    }

    private mutating func receiveContinuationRequest_expectingLiteralContinuationRequest(request: ContinuationRequest) throws -> ContinuationRequestAction {
        switch self.state {
        case .expectingNormalResponse, .idle, .authenticating, .appending, .error:
            throw UnexpectedContinuationRequest()
        case .expectingLiteralContinuationRequest:
            break
        }

        self.state = .expectingNormalResponse
        let result = self.extractSendableChunks()

        // safe to bang as if we've successfully received a continuation request then there
        // MUST be something to send
        if result.last!.0.waitForContinuation { // we've found a continuation
            self.state = .expectingLiteralContinuationRequest
        } else {
            self.activeWritePromise = nil
            self.activeEncodeBuffer = nil
            self.state = .expectingNormalResponse
        }
        return .sendChunks(result)
    }

    private mutating func receiveContinuationRequest_authenticating(request: ContinuationRequest) throws -> ContinuationRequestAction {
        guard case .authenticating(var authenticatingStateMachine) = self.state else {
            throw UnexpectedContinuationRequest()
        }

        switch request {
        case .responseText:
            // no valid base 64, so we can assume it was empty
            try authenticatingStateMachine.receiveContinuationRequest(.data(self.makeNewBuffer()))
            self.state = .authenticating(authenticatingStateMachine)
        case .data(let byteBuffer):
            try authenticatingStateMachine.receiveContinuationRequest(.data(byteBuffer))
            self.state = .authenticating(authenticatingStateMachine)
        }
        return .fireAuthenticationChallenge
    }

    private mutating func receiveContinuationRequest_idle(request: ContinuationRequest) throws -> ContinuationRequestAction {
        guard case .idle(var idleStateMachine) = self.state else {
            preconditionFailure("Invalid state: \(self.state)")
        }

        // A continuation when in idle state means it's been confirmed
        try idleStateMachine.receiveContinuationRequest(request)
        self.state = .idle(idleStateMachine)
        return .fireIdleStarted
    }
}

// MARK: - Send

extension ClientStateMachine {
    private mutating func sendCommand_state_normalResponse(command: CommandStreamPart) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingLiteralContinuationRequest, .idle, .authenticating, .appending, .error:
            preconditionFailure("Invalid state: \(self.state)")
        case .expectingNormalResponse:
            break
        }

        switch command {
        case .idleDone, .continuationResponse:
            preconditionFailure("Invalid command for state")
        case .tagged(let tc):
            return self.sendTaggedCommand(tc)
        case .append(let ac):
            return self.sendAppendCommand(ac)
        }
    }

    private mutating func sendTaggedCommand(_ command: TaggedCommand) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingLiteralContinuationRequest, .idle, .authenticating, .appending, .error:
            preconditionFailure("Invalid state: \(self.state)")
        case .expectingNormalResponse:
            break
        }

        // update the state
        let chunk = self.activeEncodeBuffer.buffer.nextChunk()
        switch command.command {
        case .idleStart:
            self.guardAgainstMultipleRunningCommands(.tagged(command))
            self.state = .idle(Idle())
        case .authenticate:
            self.guardAgainstMultipleRunningCommands(.tagged(command))
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

    private mutating func sendAppendCommand(_ command: AppendCommand) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .expectingLiteralContinuationRequest, .idle, .authenticating, .appending, .error:
            preconditionFailure("Invalid state: \(self.state)")
        case .expectingNormalResponse:
            break
        }

        // no other commands can be running when we start appending
        self.guardAgainstMultipleRunningCommands(.append(command))
        self.state = .appending(Append())

        // TODO: This assumes that the append command doesn't require a continuation - fix this in another PR
        let chunk = self.activeEncodeBuffer.buffer.nextChunk()
        let promise = self.activeWritePromise
        self.activeEncodeBuffer = nil
        self.activeWritePromise = nil
        return [(chunk, promise)]
    }

    /// Iterate through the current command queue until we reached the marked position
    /// or encounter a command that requires a continuation request to complete.
    private mutating func extractSendableChunks() -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        // If we have an encode buffer then we're waiting on a continuation
        // request, so there are no sendable chunks.
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
                result.append(contentsOf: self.sendNextCommand())
            }
            return result
        }
    }

    /// Throws an error if more than one command is running, otherwise does nothing.
    /// End users are required to ensure command pipelining compatibility.
    private func guardAgainstMultipleRunningCommands(_: CommandStreamPart) {
        precondition(self.activeCommandTags.count == 1)
    }

    private func makeNewBuffer() -> ByteBuffer {
        self.allocator.buffer(capacity: 128)
    }

    private mutating func sendNextCommand() -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        assert(self.queuedCommands.count > 0)

        guard self.activeEncodeBuffer == nil else {
            return []
        }

        let (command, promise) = self.queuedCommands.popFirst()! // we've asserted there's at least one
        switch self.state {
        case .expectingNormalResponse:
            return self.sendNextCommand_expectingNormalResponse(command: command, promise: promise)
        case .idle:
            return self.sendNextCommand_idle(command: command, promise: promise)
        case .authenticating:
            return self.sendNextCommand_authenticating(command: command, promise: promise)
        case .appending:
            return self.sendNextCommand_appending(command: command, promise: promise)
        case .expectingLiteralContinuationRequest:
            return self.sendNextCommand_expectingLiteralContinuationRequest()
        case .error:
            preconditionFailure("Already in error state, make sure to handle errors appropriately.")
        }
    }

    /// If we're "expecting a normal response" then we aren't waiting for a continuation request. However, the
    /// command we want to send may require a continuation itself. We begin by writing the command to
    /// an encode buffer to isolate any required continuations, and then send every chunk until we run out of chunks
    /// to send, or we find a chunk that requires a continuation request.
    private mutating func sendNextCommand_expectingNormalResponse(command: CommandStreamPart, promise: EventLoopPromise<Void>?) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        switch self.state {
        case .idle, .authenticating, .appending, .expectingLiteralContinuationRequest, .error:
            preconditionFailure("Invalid state: \(self.state)")
        case .expectingNormalResponse:
            break
        }

        self.activeWritePromise = promise
        self.activeEncodeBuffer = .init(buffer: self.makeNewBuffer(), options: self.encodingOptions)
        self.activeEncodeBuffer.writeCommandStream(command)
        return self.sendCommand_state_normalResponse(command: command)
    }

    /// When idle we need to first defer to the idle state machine to make sure we can send the
    /// the next part of the authentication. If we can, then just send the message. There's no need
    /// to wait for a continuation request.
    private mutating func sendNextCommand_idle(command: CommandStreamPart, promise: EventLoopPromise<Void>?) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard case .idle(var idleStateMachine) = self.state else {
            preconditionFailure("Invalid state: \(self.state)")
        }

        if idleStateMachine.sendCommand(command) {
            self.state = .expectingNormalResponse
        } else {
            self.state = .idle(idleStateMachine)
        }
        var encodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
        encodeBuffer.writeCommandStream(command)
        return [(encodeBuffer.buffer.nextChunk(), promise)]
    }

    /// When authenticating we need to first defer to the authentication state machine to make sure
    /// can send the next part of the authentication. If we can, then just send the message. There's
    /// no need to wait for a continuation request.
    private mutating func sendNextCommand_authenticating(command: CommandStreamPart, promise: EventLoopPromise<Void>?) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard case .authenticating(var authenticatingStateMachine) = self.state else {
            preconditionFailure("Invalid state: \(self.state)")
        }

        authenticatingStateMachine.sendCommand(command)
        self.state = .authenticating(authenticatingStateMachine)
        var encodeBuffer = CommandEncodeBuffer(buffer: self.makeNewBuffer(), options: self.encodingOptions)
        encodeBuffer.writeCommandStream(command)
        return [(encodeBuffer.buffer.nextChunk(), promise)]
    }

    /// When appending we need to first defer to the appending state machine to see if we can actually
    /// send a command given our current state. If we can then we need to check what kind of command
    /// is being sent. If we're beginning an append or catenation then we need to wait for a continuation
    /// request, otherwise we can send the command and continue.
    private mutating func sendNextCommand_appending(command: CommandStreamPart, promise: EventLoopPromise<Void>?) -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        guard case .appending(var appendingStateMachine) = self.state else {
            preconditionFailure("Invalid state: \(self.state)")
        }

        defer {
            appendingStateMachine.sendCommand(command)
            self.state = .appending(appendingStateMachine)
        }

        switch command {
        case .append(.beginMessage), .append(.catenateData(.begin)):
            self.activeWritePromise = promise
            self.activeEncodeBuffer = .init(
                buffer: self.makeNewBuffer(),
                options: self.encodingOptions,
                encodedAtLeastOneCatenateElement: appendingStateMachine.hasCatenatedAtLeastOneObject
            )
            self.activeEncodeBuffer.writeCommandStream(command)
            return [(self.activeEncodeBuffer.buffer.nextChunk(), self.activeWritePromise)]
        default:
            var encodeBuffer = CommandEncodeBuffer(
                buffer: self.makeNewBuffer(),
                options: self.encodingOptions,
                encodedAtLeastOneCatenateElement: appendingStateMachine.hasCatenatedAtLeastOneObject
            )
            encodeBuffer.writeCommandStream(command)
            return [(encodeBuffer.buffer.nextChunk(), promise)]
        }
    }

    /// If we're currently waiting for a continuation request then we can't send a command, so return nothing.
    private mutating func sendNextCommand_expectingLiteralContinuationRequest() -> [(EncodeBuffer.Chunk, EventLoopPromise<Void>?)] {
        []
    }
}
