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
import CoreImage

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

    public init(encodingChangeCallback: @escaping (OrderedDictionary<String, String?>, inout CommandEncodingOptions) -> Void = { _, _ in }) {
        self.state = .init()
        self.decoder = NIOSingleStepByteToMessageProcessor(ResponseDecoder(), maximumBufferSize: 1_000)
        self.encodingChangeCallback = encodingChangeCallback
        self.lastKnownCapabilities = []
        self.encodingOptions = CommandEncodingOptions(capabilities: self.lastKnownCapabilities)
    }

    public func channelInactive(context: ChannelHandlerContext) {
        context.fireChannelInactive()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        do {
            try self.decoder.process(buffer: data) { response in
                try self.handleResponseOrContinuationRequest(response, context: context)
            }
        } catch {
            context.fireErrorCaught(error)
        }
    }

    private func handleResponseOrContinuationRequest(_ response: ResponseOrContinuationRequest, context: ChannelHandlerContext) throws {
        switch response {
        case .continuationRequest(let continuationRequest):
            let chunks = try self.state.receiveContinuationRequest(continuationRequest)
            self.writeChunks(chunks, context: context)
        case .response(let response):
            try self.state.receiveResponse(response)
            context.fireChannelRead(self.wrapInboundOut(response))
        }
    }
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let command = self.unwrapOutboundIn(data)
        do {
            let chunks = try self.state.sendCommand(command, promise: promise)
            self.writeChunks(chunks, context: context)
        } catch {
            // TODO: Handle
        }
    }
    
    private func writeChunks(_ chunks: [(ByteBuffer, EventLoopPromise<Void>?)], context: ChannelHandlerContext) {
        for (buffer, promise) in chunks {
            let outbound = self.wrapOutboundOut(buffer)
            context.writeAndFlush(outbound, promise: promise)
        }
    }
}
