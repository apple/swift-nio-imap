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
    public typealias OutboundIn = ResponseOrContinuationRequest
    public typealias OutboundOut = ByteBuffer

    private var _continuationRequest: ContinuationRequest
    public var continuationRequest: ContinuationRequest {
        get {
            self._continuationRequest
        }
        set {
            self._continuationRequest = newValue
            let buffer = ByteBufferAllocator().buffer(capacity: 16)
            var encodeBuffer = ResponseEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
            encodeBuffer.writeContinuationRequest(newValue)
            self.continuationRequestBytes = encodeBuffer.readBytes()
        }
    }

    private let decoder: NIOSingleStepByteToMessageProcessor<CommandDecoder>
    private var numberOfOutstandingContinuationRequests = 0
    private var continuationRequestBytes: ByteBuffer

    private var responseEncodeBuffer = ResponseEncodeBuffer(buffer: ByteBuffer(string: ""), options: .init())

    public var capabilities: [Capability] = []

    public init(continuationRequest: ContinuationRequest = .responseText(ResponseText(text: "OK"))) {
        self.decoder = NIOSingleStepByteToMessageProcessor(CommandDecoder(), maximumBufferSize: 1_000)
        self._continuationRequest = continuationRequest
        let buffer = ByteBufferAllocator().buffer(capacity: 16)
        var encodeBuffer = ResponseEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
        encodeBuffer.writeContinuationRequest(continuationRequest)
        self.continuationRequestBytes = encodeBuffer.readBytes()
    }

    public func read(context: ChannelHandlerContext) {
        defer {
            context.read()
        }
        let outstanding = self.numberOfOutstandingContinuationRequests
        if outstanding == 0 {
            return
        }

        for _ in 0 ..< outstanding {
            context.write(self.wrapOutboundOut(self.continuationRequestBytes), promise: nil)
        }
        context.flush()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        do {
            try self.decoder.process(buffer: self.unwrapInboundIn(data)) { command in
                self.numberOfOutstandingContinuationRequests += command.numberOfSynchronisingLiterals
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
        self.responseEncodeBuffer.writeResponseOrContinuationRequest(response)
        context.write(self.wrapOutboundOut(self.responseEncodeBuffer.readBytes()), promise: promise)
    }
}
