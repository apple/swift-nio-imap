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
import NIOSSL
import NIOIMAP
import Logging
import NIOIMAPCore

public class CommandRoundtripHandler: ChannelOutboundHandler {
    
    public typealias OutboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    
    let logger: Logger
    private var parser = NIOIMAP.CommandParser()
    
    public init(logger: Logger) {
        self.logger = logger
    }
    
    public func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var originalBuffer = self.unwrapOutboundIn(data)
        do {
            var originalBufferCopy = originalBuffer
            guard let commandStream = try parser.parseCommandStream(buffer: &originalBufferCopy) else {
                promise?.fail(NIOIMAP.ParsingError.incompleteMessage) // TODO: this leaks implementation details
                return
            }
            
            var roundtripBuffer = context.channel.allocator.buffer(capacity: originalBuffer.readableBytes)
            roundtripBuffer.writeCommandStream(commandStream)
            
            if originalBuffer != roundtripBuffer {
                logger.warning("Input command vs roundtrip output is different")
                logger.warning("Command (original):\n\(originalBuffer.readString(length: originalBuffer.readableBytes)!)")
                logger.warning("Command (roundtrip):\n\(roundtripBuffer.readString(length: roundtripBuffer.readableBytes)!)")
            }
            
            context.write(data, promise: promise)
        } catch {
            promise?.fail(error)
            context.fireErrorCaught(error)
        }
        
    }
}
