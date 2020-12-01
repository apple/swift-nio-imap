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
    private var bufferedWrites: MarkedCircularBuffer<(EncodeBuffer, EventLoopPromise<Void>?)> =
        MarkedCircularBuffer(initialCapacity: 4)

    public struct UnexpectedContinuationRequest: Error {}

    public init() {
        self.decoder = NIOSingleStepByteToMessageProcessor(ResponseDecoder(), maximumBufferSize: 1_000)
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        do {
            try self.decoder.process(buffer: data) { response in
                switch response {
                case .continuationRequest:
                    self.writeNextChunks(context: context)
                case .response(let response):
                    let out = ResponseOrContinuationRequest.response(response)
                    context.fireChannelRead(self.wrapInboundOut(out))
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
            let next = self.bufferedWrites[self.bufferedWrites.startIndex].0.nextChunk()

            if next.waitForContinuation {
                context.write(self.wrapOutboundOut(next.bytes), promise: nil)
                return
            } else {
                let promise = self.bufferedWrites.removeFirst().1
                context.write(self.wrapOutboundOut(next.bytes), promise: promise)
            }
        } while self.bufferedWrites.hasMark
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let command = self.unwrapOutboundIn(data)
        var encoder = CommandEncodeBuffer(buffer: context.channel.allocator.buffer(capacity: 1024), capabilities: [])
        encoder.writeCommandStream(command)
        if self.bufferedWrites.isEmpty {
            let next = encoder.buffer.nextChunk()

            if next.waitForContinuation {
                context.write(self.wrapOutboundOut(next.bytes), promise: nil)
                // fall through to append below
            } else {
                context.write(self.wrapOutboundOut(next.bytes), promise: promise)
                return
            }
        }
        self.bufferedWrites.append((encoder.buffer, promise))
    }

    public func flush(context: ChannelHandlerContext) {
        self.bufferedWrites.mark()
        context.flush()
    }
}
