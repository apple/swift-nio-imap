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

import Logging
import NIO
import NIOIMAP
import NIOIMAPCore
import NIOSSL

enum CommandRoundtripError: Error {
    case incompleteCommand
}

public class CommandRoundtripHandler: ChannelOutboundHandler {
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer

    let logger: Logger
    private var parser = CommandParser()
    public var capabilities: [Capability] = []

    public init(logger: Logger) {
        self.logger = logger
    }

    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var originalBuffer = self.unwrapOutboundIn(data)
        do {
            var originalBufferCopy = originalBuffer
            guard let commandStream = try parser.parseCommandStream(buffer: &originalBufferCopy), let command = commandStream.command else {
                // this is fine because the command is input by the user, so *should* be valid
                throw CommandRoundtripError.incompleteCommand
            }

            var encodeBuffer = CommandEncodeBuffer(
                buffer: context.channel.allocator.buffer(capacity: originalBuffer.readableBytes),
                capabilities: self.capabilities
            )
            encodeBuffer.writeCommandStream(command)
            var roundtripBuffer = encodeBuffer._buffer.nextChunk().bytes

            if originalBuffer != roundtripBuffer {
                self.logger.warning("Input command vs roundtrip output is different")
                self.logger.warning("Command (original):\n\(originalBuffer.readString(length: originalBuffer.readableBytes)!)")
                self.logger.warning("Command (roundtrip):\n\(roundtripBuffer.readString(length: roundtripBuffer.readableBytes)!)")
            }

            context.write(data, promise: promise)
        } catch {
            promise?.fail(error)
            context.fireErrorCaught(error)
        }
    }
}
