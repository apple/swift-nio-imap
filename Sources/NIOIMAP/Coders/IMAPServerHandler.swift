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

public struct ReceivedInvalidFrame: Hashable, Sendable {
    public var frame: ByteBuffer

    public init(frame: ByteBuffer) {
        self.frame = frame
    }
}

public struct ReceivedIncompleteFrame: Hashable, Sendable {
    public var requiredBytes: Int

    public init(requiredBytes: Int) {
        self.requiredBytes = requiredBytes
    }
}

public final class IMAPServerHandler: ChannelDuplexHandler {
    public typealias InboundIn = FramingResult
    public typealias InboundOut = CommandStreamPart
    public typealias OutboundIn = Response
    public typealias OutboundOut = ByteBuffer

    private var _continuationRequest: ContinuationRequest
    public var continuationRequest: ContinuationRequest {
        get {
            self._continuationRequest
        }
        set {
            self._continuationRequest = newValue
            let buffer = ByteBufferAllocator().buffer(capacity: 16)
            var encodeBuffer = ResponseEncodeBuffer(buffer: buffer, capabilities: self.capabilities, loggingMode: false)
            encodeBuffer.writeContinuationRequest(newValue)
            self.continuationRequestBytes = encodeBuffer.readBytes()
        }
    }

    private let decoder: NIOSingleStepByteToMessageProcessor<CommandDecoder>
    private var numberOfOutstandingContinuationRequests = 0
    private var continuationRequestBytes: ByteBuffer

    private var responseEncodeBuffer = ResponseEncodeBuffer(
        buffer: ByteBuffer(string: ""),
        options: .init(),
        loggingMode: false
    )

    public var capabilities: [Capability] = []

    public init(
        continuationRequest: ContinuationRequest = .responseText(ResponseText(text: "OK")),
        literalSizeLimit: Int = IMAPDefaults.literalSizeLimit
    ) {
        self.decoder = NIOSingleStepByteToMessageProcessor(
            CommandDecoder(literalSizeLimit: literalSizeLimit),
            maximumBufferSize: IMAPDefaults.lineLengthLimit
        )
        self._continuationRequest = continuationRequest
        let buffer = ByteBufferAllocator().buffer(capacity: 16)
        var encodeBuffer = ResponseEncodeBuffer(buffer: buffer, capabilities: self.capabilities, loggingMode: false)
        encodeBuffer.writeContinuationRequest(continuationRequest)
        self.continuationRequestBytes = encodeBuffer.readBytes()
    }

    public func read(context: ChannelHandlerContext) {
        defer {
            context.read()
        }
        let outstanding = self.numberOfOutstandingContinuationRequests
        guard outstanding != 0 else { return }

        for _ in 0..<outstanding {
            context.write(self.wrapOutboundOut(self.continuationRequestBytes), promise: nil)
        }
        self.numberOfOutstandingContinuationRequests = 0
        context.flush()
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)
        switch frame {
        case .complete(let buffer), .insideLiteral(let buffer, remainingBytes: _):
            do {
                try self.decoder.process(buffer: buffer) { command in
                    self.numberOfOutstandingContinuationRequests += command.numberOfSynchronisingLiterals
                    if let command = command.commandPart {
                        context.fireChannelRead(self.wrapInboundOut(command))
                    }
                }
            } catch {
                context.fireErrorCaught(error)
            }
        case .incomplete(let requiredBytes):
            context.fireUserInboundEventTriggered(ReceivedIncompleteFrame(requiredBytes: requiredBytes))
        case .invalid(let buffer):
            context.fireUserInboundEventTriggered(ReceivedInvalidFrame(frame: buffer))
        }
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let response = self.unwrapOutboundIn(data)
        self.responseEncodeBuffer.writeResponse(response)
        context.write(self.wrapOutboundOut(self.responseEncodeBuffer.readBytes()), promise: promise)
    }
}
