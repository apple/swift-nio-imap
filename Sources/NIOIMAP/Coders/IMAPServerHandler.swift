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
            self.continuationRequestBytes = Self.encode(newValue, capabilities: self.capabilities)
        }
    }

    /// Received bytes, parsed where they landed rather than coalesced into one buffer first.
    private let decoder: IMAPInputProcessor<CommandDecoder>
    private var numberOfOutstandingContinuationRequests = 0

    /// The encoded continuation request, written once per outstanding request.
    ///
    /// Coalesced into one `ByteBuffer` rather than kept as regions, because it is a handful of bytes
    /// that gets written many times over the life of the connection.
    private var continuationRequestBytes: ByteBuffer

    /// The buffer every response is encoded into, kept for the lifetime of the connection.
    ///
    /// Default sink, `IMAPOutputBuffer`, on purpose: ``ByteBufferOutput`` would hand the channel slices
    /// rather than copies, but it allocates a fresh `ByteBuffer` per chunk while earlier ones are still
    /// in flight, and is slower on a stream of small responses.
    private var responseEncodeBuffer = ResponseEncodeBuffer(
        options: .init(),
        loggingMode: false
    )

    public var capabilities: [Capability] = []

    public init(
        continuationRequest: ContinuationRequest = .responseText(ResponseText(text: "OK")),
        literalSizeLimit: Int = IMAPDefaults.literalSizeLimit
    ) {
        self.decoder = IMAPInputProcessor(
            CommandDecoder(literalSizeLimit: literalSizeLimit),
            maximumBufferSize: IMAPDefaults.lineLengthLimit
        )
        self._continuationRequest = continuationRequest
        self.continuationRequestBytes = Self.encode(continuationRequest, capabilities: self.capabilities)
    }

    /// Encodes one continuation request into a single `ByteBuffer`.
    private static func encode(_ request: ContinuationRequest, capabilities: [Capability]) -> ByteBuffer {
        var encodeBuffer = ResponseEncodeBuffer(capabilities: capabilities, loggingMode: false)
        encodeBuffer.writeContinuationRequest(request)
        return encodeBuffer.readBytes().makeByteBuffer()
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
        let bytes = self.responseEncodeBuffer.readBytes()
        // Usually one write. Several when the response carries a payload the encoder kept by reference —
        // a streamed literal — so that the payload reaches the network without being copied. See
        // `IMAPBufferList.makeOutboundBuffers()`.
        switch bytes.regionCount {
        case 0:
            context.write(self.wrapOutboundOut(ByteBuffer()), promise: promise)
        case 1:
            context.write(self.wrapOutboundOut(bytes.regions[0].byteBuffer), promise: promise)
        default:
            let buffers = bytes.makeOutboundBuffers()
            for (index, buffer) in buffers.enumerated() {
                let outbound = self.wrapOutboundOut(buffer)
                if index == buffers.count - 1 {
                    context.write(outbound, promise: promise)
                } else {
                    context.write(outbound).cascadeFailure(to: promise)
                }
            }
        }
    }
}

// `IMAPServerHandler` holds per-connection mutable state and is confined to a
// single `EventLoop`, so it is deliberately non-`Sendable`.
@available(*, unavailable)
extension IMAPServerHandler: Sendable {}
