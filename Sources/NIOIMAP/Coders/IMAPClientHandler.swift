//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2020 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import OrderedCollections
import NIO
import NIOIMAPCore

/// To be used by a IMAP client implementation.
public final class IMAPClientHandler: ChannelDuplexHandler {
    /// Should receive a raw buffer in, after any TLS.
    public typealias InboundIn = ByteBuffer

    /// Converts a `ByteBuffer` into a `Response` by sending data through a parser.
    public typealias InboundOut = Response

    /// Commands are encoding into a ByteBuffer to send to a server.
    public typealias OutboundIn = CommandStream

    /// After encoding the bytes may be sent further through the channel to, for example, a TLS handler.
    public typealias OutboundOut = ByteBuffer

    private let decoder: NIOSingleStepByteToMessageProcessor<ResponseDecoder>
    private var bufferedWrites: MarkedCircularBuffer<(_EncodeBuffer, EventLoopPromise<Void>?)> =
        MarkedCircularBuffer(initialCapacity: 4)

    public struct UnexpectedContinuationRequest: Error {}

    public struct UnexpectedResponse: Error {}

    var state: ClientHandlerState

    /// Capabilites are sent by an IMAP server. Once the desired capabilities have been
    /// select from the server's response, update these encoding options to enable or disable
    /// certain types of literal encodings.
    /// - Note: Make sure to send `.enable` commands for applicable capabilities
    /// - Important: Modifying this value is not thread-safe
    private var encodingOptions: CommandEncodingOptions

    private var lastKnownCapabilities = [Capability]()

    /// This function is called by the `IMAPChannelHandler` upon receipt of a response containing capabilities.
    /// The first argument is the capabilities that the server has sent. The second is a mutable set of encoding options.
    /// The encoding options are pre-populated with what are considered to be the *best* settings for the given
    /// capabilities.
    var encodingChangeCallback: (OrderedDictionary<String, String?>, inout CommandEncodingOptions) -> Void

    enum ClientHandlerState: Equatable {
        /// We're expecting a continuation from an idle command
        case expectingIdleContinuation

        /// We're expecting authentication challenges when running an authentication command
        case expectingAuthenticationChallenges

        case expectingLiteralContinuationRequest

        /// We expect the server to return standard tagged or untagged responses, without any intermediate
        /// continuations, with the exception of synchronising literals.
        case expectingResponses

        case error
    }

    public init(encodingChangeCallback: @escaping (OrderedDictionary<String, String?>, inout CommandEncodingOptions) -> Void = { _, _ in }) {
        self.decoder = NIOSingleStepByteToMessageProcessor(ResponseDecoder(), maximumBufferSize: 1_000)
        self.state = .expectingResponses
        self.encodingChangeCallback = encodingChangeCallback
        self.lastKnownCapabilities = []
        self.encodingOptions = CommandEncodingOptions(capabilities: self.lastKnownCapabilities)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        do {
            try self.decoder.process(buffer: data) { response in
                self.handleResponseOrContinuationRequest(response, context: context)
            }
        } catch {
            context.fireErrorCaught(error)
        }
    }

    private func handleResponseOrContinuationRequest(_ response: ResponseOrContinuationRequest, context: ChannelHandlerContext) {
        switch self.state {
        case .expectingLiteralContinuationRequest:
            switch response {
            case .continuationRequest(let req):
                self.handleContinuationRequest(req, context: context)
            case .response:
                context.fireErrorCaught(UnexpectedResponse())
            }

        case .expectingResponses:
            switch response {
            case .continuationRequest:
                context.fireErrorCaught(IMAPClientHandler.UnexpectedContinuationRequest())
            case .response(let response):
                self.handleResponse(response, context: context)
            }

        case .expectingAuthenticationChallenges:
            switch response {
            case .continuationRequest(let req):
                self.handleContinuationRequest(req, context: context)
            case .response(let response):
                self.handleResponse(response, context: context)
            }

        case .expectingIdleContinuation:
            switch response {
            case .continuationRequest(let req):
                self.handleContinuationRequest(req, context: context)
            case .response:
                context.fireErrorCaught(UnexpectedResponse())
            }

        case .error:
            context.fireErrorCaught(UnexpectedResponse())
        }
    }

    private func handleResponse(_ response: Response, context: ChannelHandlerContext) {
        switch response {
        case .taggedResponse:
            // continuations must have finished: change the state to standard continuation handling
            self.state = .expectingResponses
        case .untaggedResponse(let untagged):
            switch untagged {
            case .conditionalState, .mailboxData, .messageData, .enableData, .quotaRoot, .quota, .metadata:
                break
            case .capabilityData(let caps):
                self.lastKnownCapabilities = caps
            case .id(let info):
                var recomended = CommandEncodingOptions(capabilities: self.lastKnownCapabilities)
                self.encodingChangeCallback(info, &recomended)
                self.encodingOptions = recomended
            }
        case .fetchResponse, .fatalResponse, .authenticationChallenge:
            break
        case .idleStarted:
            self.state = .expectingIdleContinuation
        }
        context.fireChannelRead(self.wrapInboundOut(response))
    }

    private func handleContinuationRequest(_ req: ContinuationRequest, context: ChannelHandlerContext) {
        switch self.state {
        case .expectingIdleContinuation:
            self.state = .expectingResponses // there should only be one idle continuation
            context.fireChannelRead(self.wrapInboundOut(.idleStarted))
        case .expectingAuthenticationChallenges:
            context.fireChannelRead(self.wrapInboundOut(self.handleAuthenticationChallenge(req)))
            return // don't forward as a user event - it should be consumed
        case .expectingResponses:
            context.fireErrorCaught(UnexpectedContinuationRequest())
        case .expectingLiteralContinuationRequest:
            self.writeNextChunks(context: context)
        case .error:
            context.fireErrorCaught(UnexpectedResponse())
        }
        context.fireUserInboundEventTriggered(req)
    }

    private func handleAuthenticationChallenge(_ req: ContinuationRequest) -> InboundOut {
        switch req {
        case .data(let bytes):
            return .authenticationChallenge(bytes)
        case .responseText:
            // there wasn't any valid base 64
            // so return an empty data
            return .authenticationChallenge(ByteBuffer())
        }
    }

    private func writeNextChunks(context: ChannelHandlerContext) {
        assert(self.bufferedWrites.hasMark)
        defer {
            // Note, we can `flush` here because this is already flushed (or else the we wouldn't have a mark).
            context.flush()
        }
        repeat {
            let next = self.bufferedWrites[self.bufferedWrites.startIndex].0.nextChunk()

            if next.waitForContinuation {
                assert(self.state == .expectingResponses || self.state == .expectingLiteralContinuationRequest)
                self.state = .expectingLiteralContinuationRequest
                context.write(self.wrapOutboundOut(next.bytes), promise: nil)
                return
            } else {
                assert(self.state == .expectingLiteralContinuationRequest)
                self.state = .expectingResponses
                let promise = self.bufferedWrites.removeFirst().1
                context.write(self.wrapOutboundOut(next.bytes), promise: promise)
            }
        } while self.bufferedWrites.hasMark
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        precondition(self.bufferedWrites.isEmpty, "Sorry, we only allow one command at a time right now. We're working on it. Issue #528")
        let command = self.unwrapOutboundIn(data)
        var encoder = CommandEncodeBuffer(buffer: context.channel.allocator.buffer(capacity: 1024), options: self.encodingOptions)
        encoder.writeCommandStream(command)

        switch command {
        case .command(let command):
            switch command.command {
            case .idleStart:
                assert(self.state == .expectingResponses)
                self.state = .expectingIdleContinuation
            case .authenticate(mechanism: _, initialResponse: _):
                assert(self.state == .expectingResponses)
                self.state = .expectingAuthenticationChallenges
            default:
                assert(self.state == .expectingResponses)
                self.state = .expectingResponses
            }
        case .idleDone:
            assert(self.state == .expectingResponses)
            self.state = .expectingResponses
        default:
            break
        }

        if self.bufferedWrites.isEmpty {
            let next = encoder._buffer.nextChunk()

            if next.waitForContinuation {
                assert(self.state == .expectingResponses)
                self.state = .expectingLiteralContinuationRequest
                context.write(self.wrapOutboundOut(next.bytes), promise: nil)
                // fall through to append below
            } else {
                context.write(self.wrapOutboundOut(next.bytes), promise: promise)
                return
            }
        }
        self.bufferedWrites.append((encoder._buffer, promise))
    }

    public func flush(context: ChannelHandlerContext) {
        self.bufferedWrites.mark()
        context.flush()
    }
}
