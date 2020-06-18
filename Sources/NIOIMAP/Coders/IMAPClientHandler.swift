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

public final class IMAPClientHandler: ChannelDuplexHandler {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = Response
    public typealias OutboundIn = CommandStream
    public typealias OutboundOut = ByteBuffer

    private let decoder: NIOSingleStepByteToMessageProcessor<ResponseDecoder>
    private var bufferedWrites: MarkedCircularBuffer<(EncodeBuffer, EventLoopPromise<Void>?)> =
        MarkedCircularBuffer(initialCapacity: 4)

    public struct UnexpectedContinuationRequest: Error {}

    var capabilities: EncodingCapabilities = []

    public init(expectGreeting: Bool) {
        self.decoder = NIOSingleStepByteToMessageProcessor(ResponseDecoder(expectGreeting: expectGreeting))
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let data = self.unwrapInboundIn(data)
        do {
            try self.decoder.process(buffer: data) { response in
                switch response {
                case .continueRequest:
                    self.writeNextChunks(context: context)
                case .response(let response):
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
        var encoder = CommandEncodeBuffer(buffer: context.channel.allocator.buffer(capacity: 1024), capabilities: self.capabilities)
        do {
            try encoder.writeCommandStream(command)
        } catch {
            promise?.fail(error)
            context.fireErrorCaught(error)
            return
        }
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
