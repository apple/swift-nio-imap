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

import NIO
@_spi(NIOIMAPInternal) import NIOIMAPCore
import OrderedCollections

/// To be used by a IMAP client implementation.
public final class IMAPClientHandler: ChannelDuplexHandler {
    /// Should receive a raw buffer in, after any TLS.
    public typealias InboundIn = ByteBuffer

    /// Converts a `ByteBuffer` into a `Response` by sending data through a parser.
    public typealias InboundOut = Response

    /// Commands are encoding into a ByteBuffer to send to a server.
    public typealias OutboundIn = CommandStreamPart

    /// After encoding the bytes may be sent further through the channel to, for example, a TLS handler.
    public typealias OutboundOut = ByteBuffer

    private let decoder: NIOSingleStepByteToMessageProcessor<ResponseDecoder>

    private var state: ClientStateMachine

    private var lastKnownCapabilities = [Capability]()

    /// This function is called by the `IMAPChannelHandler` upon receipt of a response containing capabilities.
    /// The first argument is the capabilities that the server has sent. The second is a mutable set of encoding options.
    /// The encoding options are pre-populated with what are considered to be the *best* settings for the given
    /// capabilities.
    var encodingChangeCallback: (OrderedDictionary<String, String?>, inout CommandEncodingOptions) -> Void

    public init(
        encodingChangeCallback: @escaping (OrderedDictionary<String, String?>, inout CommandEncodingOptions) -> Void = {
            _,
            _ in
        }
    ) {
        self.state = .init(encodingOptions: CommandEncodingOptions(capabilities: self.lastKnownCapabilities))
        self.decoder = NIOSingleStepByteToMessageProcessor(
            ResponseDecoder(),
            maximumBufferSize: IMAPDefaults.lineLengthLimit
        )
        self.encodingChangeCallback = encodingChangeCallback
        self.lastKnownCapabilities = []
    }

    public func channelInactive(context: ChannelHandlerContext) {
        let pendingWritePromises = self.state.channelInactive()
        pendingWritePromises.forEach { $0.fail(ChannelError.ioOnClosedChannel) }
        context.fireChannelInactive()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        do {
            try self.decoder.process(buffer: data) { response in
                try self.handleResponseOrContinuationRequest(response, context: context)
            }
        } catch let error as UnexpectedResponse {
            error.activePromise?.fail(error)
            context.fireErrorCaught(error)
        } catch {
            context.fireErrorCaught(error)
        }
    }

    public func handlerAdded(context: ChannelHandlerContext) {
        self.state.handlerAdded(context.channel.allocator)
        context.fireChannelActive()
    }

    private func handleResponseOrContinuationRequest(
        _ response: ResponseOrContinuationRequest,
        context: ChannelHandlerContext
    ) throws {
        switch response {
        case .continuationRequest(let continuationRequest):
            let action = try self.state.receiveContinuationRequest(continuationRequest)
            self.handleContinuationRequestAction(action, request: continuationRequest, context: context)
        case .response(let response):
            try self.state.receiveResponse(response)
            context.fireChannelRead(self.wrapInboundOut(response))
            switch response {
            case .untagged(.capabilityData(let caps)):
                self.lastKnownCapabilities = caps
            case .untagged(.id(let info)):
                var recomended = CommandEncodingOptions(capabilities: self.lastKnownCapabilities)
                self.encodingChangeCallback(info, &recomended)
                self.state.encodingOptions = recomended
            default:
                break
            }
        }
    }

    private func handleContinuationRequestAction(
        _ action: ClientStateMachine.ContinuationRequestAction,
        request: ContinuationRequest,
        context: ChannelHandlerContext
    ) {
        switch action {
        case .sendChunks(let chunks):
            self.writeChunks(chunks, context: context)
            context.fireUserInboundEventTriggered(request)
        case .fireIdleStarted:
            context.fireChannelRead(self.wrapInboundOut(.idleStarted))
            context.fireUserInboundEventTriggered(request)
        case .fireAuthenticationChallenge:
            switch request {
            case .responseText:
                // No valid base64, so forward on an empty BB
                context.fireChannelRead(
                    self.wrapInboundOut(.authenticationChallenge(context.channel.allocator.buffer(capacity: 0)))
                )
            case .data(let byteBuffer):
                context.fireChannelRead(self.wrapInboundOut(.authenticationChallenge(byteBuffer)))
            }
        }
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let command = self.unwrapOutboundIn(data)
        do {
            if let chunk = try self.state.sendCommand(command, promise: promise) {
                self.writeChunk(chunk, context: context)
            }
        } catch {
            context.fireErrorCaught(error)
            promise?.fail(error)
        }
    }

    private func writeChunks(_ chunks: [OutgoingChunk], context: ChannelHandlerContext) {
        guard chunks.count > 0 else { return }
        chunks.forEach { chunk in
            self.writeChunk(chunk, context: context)
        }
        context.flush()  // we wouldn't reach this point if we hadn't already flushed
    }

    private func writeChunk(_ chunk: OutgoingChunk, context: ChannelHandlerContext) {
        let outbound = self.wrapOutboundOut(chunk.bytes)
        if chunk.shouldSucceedPromise {
            context.write(outbound, promise: chunk.promise)
        } else {
            context.write(outbound).cascadeFailure(to: chunk.promise)
        }
    }

    public func flush(context: ChannelHandlerContext) {
        self.state.flush()
        context.flush()
    }
}
