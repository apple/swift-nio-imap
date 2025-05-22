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

    /// Either `CommandStreamPart` or options.
    public typealias OutboundIn = Message

    /// After encoding the bytes may be sent further through the channel to, for example, a TLS handler.
    public typealias OutboundOut = ByteBuffer

    /// We can receive either `CommandStreamPart` or `EncodingOptions`.
    public enum Message: Hashable, Sendable {
        case part(CommandStreamPart)
        case setEncodingOptions(EncodingOptions)
    }

    private let decoder: NIOSingleStepByteToMessageProcessor<ResponseDecoder>

    private var state: ClientStateMachine

    public init(
        encodingOptions: EncodingOptions = .automatic,
        parserOptions: ResponseParser.Options = ResponseParser.Options()
    ) {
        self.state = .init(encodingOptions: encodingOptions)
        self.decoder = NIOSingleStepByteToMessageProcessor(
            ResponseDecoder(
                options: parserOptions
            ),
            maximumBufferSize: IMAPDefaults.lineLengthLimit
        )
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
            self.state.encodingOptions.updateAutomaticOptions(response: response)
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
        switch self.unwrapOutboundIn(data) {
        case .part(let command):
            do {
                if let chunk = try self.state.sendCommand(command, promise: promise) {
                    self.writeChunk(chunk, context: context)
                }
            } catch {
                context.fireErrorCaught(error)
                promise?.fail(error)
            }
        case .setEncodingOptions(let options):
            state.encodingOptions.userOptions = options
            promise?.succeed()
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

extension IMAPClientHandler {
    public enum EncodingOptions: Hashable, Sendable {
        case automatic
        case fixed(CommandEncodingOptions)
    }
}
