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

    private(set) var _state: ClientHandlerState

    /// Capabilites are sent by an IMAP server. Once the desired capabilities have been
    /// select from the server's response, update these encoding options to enable or disable
    /// certain types of literal encodings.
    /// - Note: Make sure to send `.enable` commands for appicable capabilities
    /// - Important: Modifying this value is not thread-safe
    public var encodingOptions: CommandEncodingOptions

    enum ClientHandlerState: Equatable {
        /// We're expecting continuations to come back during a command.
        /// For example when in an IDLE state, the server may periodically send
        /// back "+ Still here". Note that this does not include continuations for
        /// synchronising literals.
        case expectingContinuations

        /// We expect the server to return standard tagged or untagged responses, without any intermediate
        /// continuations, with the exception of synchronising literals.
        case expectingResponses
    }

    public init(encodingOptions: CommandEncodingOptions) {
        self.decoder = NIOSingleStepByteToMessageProcessor(ResponseDecoder(), maximumBufferSize: 1_000)
        self._state = .expectingResponses
        self.encodingOptions = encodingOptions
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        do {
            try self.decoder.process(buffer: data) { response in
                switch response {
                case .continuationRequest(let req):
                    switch self._state {
                    case .expectingContinuations:
                        context.fireChannelRead(self.wrapInboundOut(.idleStarted))
                    case .expectingResponses:
                        self.writeNextChunks(context: context)
                    }
                    context.fireUserInboundEventTriggered(req)
                case .response(let response):
                    switch response {
                    case .taggedResponse:
                        // continuations must have finished: change the state to standard continuation handling
                        self._state = .expectingResponses

                    case .untaggedResponse, .fetchResponse, .fatalResponse, .authenticationChallenge, .idleStarted:
                        break
                    }
                    context.fireChannelRead(self.wrapInboundOut(response))
                }
            }
        } catch {
            context.fireErrorCaught(error)
        }
    }

    private func writeNextChunks(context: ChannelHandlerContext) {
        guard self.bufferedWrites.hasMark else {
            // This is very odd, that's a continuation request that we didn't expect.
            context.fireErrorCaught(UnexpectedContinuationRequest())
            return
        }
        defer {
            // Note, we can `flush` here because this is already flushed (or else the we wouldn't have a mark).
            context.flush()
        }
        repeat {
            let next = self.bufferedWrites[self.bufferedWrites.startIndex].0._nextChunk()

            if next._waitForContinuation {
                context.write(self.wrapOutboundOut(next._bytes), promise: nil)
                return
            } else {
                let promise = self.bufferedWrites.removeFirst().1
                context.write(self.wrapOutboundOut(next._bytes), promise: promise)
            }
        } while self.bufferedWrites.hasMark
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let command = self.unwrapOutboundIn(data)
        var encoder = CommandEncodeBuffer(buffer: context.channel.allocator.buffer(capacity: 1024), options: self.encodingOptions)
        encoder.writeCommandStream(command)

        switch command {
        case .command(let command):
            switch command.command {
            case .idleStart, .authenticate(method: _, initialClientResponse: _):
                self._state = .expectingContinuations
            default:
                self._state = .expectingResponses
            }
        case .idleDone:
            self._state = .expectingResponses
        default:
            break
        }

        if self.bufferedWrites.isEmpty {
            let next = encoder._buffer._nextChunk()

            if next._waitForContinuation {
                context.write(self.wrapOutboundOut(next._bytes), promise: nil)
                // fall through to append below
            } else {
                context.write(self.wrapOutboundOut(next._bytes), promise: promise)
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
