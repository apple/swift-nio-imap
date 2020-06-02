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

public final class IMAPServerHandler: ChannelDuplexHandler {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = CommandStream
    public typealias OutboundIn = Response
    public typealias OutboundOut = ByteBuffer

    private var _continueRequest: ContinueRequest
    public var continueRequest: ContinueRequest {
        get {
            self._continueRequest
        }
        set {
            self._continueRequest = newValue
            let buffer = ByteBufferAllocator().buffer(capacity: 16)
            var encodeBuffer = EncodeBuffer(buffer, mode: .server(), capabilities: self.capabilities)
            encodeBuffer.writeContinueRequest(newValue)
            self.continueRequestBytes = encodeBuffer.nextChunk().bytes
        }
    }

    private let decoder: NIOSingleStepByteToMessageProcessor<CommandDecoder>
    private var numberOfOutstandingContinueRequests = 0
    private var continueRequestBytes: ByteBuffer

    public var capabilities: EncodingCapabilities = []

    public init(continueRequest: ContinueRequest = .responseText(ResponseText(text: "OK"))) {
        self.decoder = NIOSingleStepByteToMessageProcessor(CommandDecoder())
        self._continueRequest = continueRequest
        let buffer = ByteBufferAllocator().buffer(capacity: 16)
        var encodeBuffer = EncodeBuffer(buffer, mode: .server(), capabilities: self.capabilities)
        encodeBuffer.writeContinueRequest(continueRequest)
        self.continueRequestBytes = encodeBuffer.nextChunk().bytes
    }

    public func read(context: ChannelHandlerContext) {
        defer {
            context.read()
        }
        let outstanding = self.numberOfOutstandingContinueRequests
        if outstanding == 0 {
            return
        }

        for _ in 0 ..< outstanding {
            context.write(self.wrapOutboundOut(self.continueRequestBytes), promise: nil)
        }
        context.flush()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            try self.decoder.process(buffer: self.unwrapInboundIn(data)) { command in
                self.numberOfOutstandingContinueRequests += command.numberOfSynchronisingLiterals
                if let command = command.command {
                    context.fireChannelRead(self.wrapInboundOut(command))
                }
            }
        } catch {
            context.fireErrorCaught(error)
        }
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: 1024)
        var encodeBuffer = EncodeBuffer(buffer, mode: .server(), capabilities: self.capabilities)
        encodeBuffer.writeResponse(response)

        buffer.clear()
        while encodeBuffer.hasMoreChunks {
            var chunk = encodeBuffer.nextChunk()
            buffer.writeBuffer(&chunk.bytes)
        }
        context.write(self.wrapOutboundOut(buffer), promise: promise)
    }
}
