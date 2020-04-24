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

public class ResponseRoundtripHandler: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias InboundOut = ByteBuffer

    let logger: Logger
    private var parser = NIOIMAP.ResponseParser()

    public init(logger: Logger) {
        self.logger = logger
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var originalBuffer = self.unwrapInboundIn(data)
        do {
            var originalBufferCopy = originalBuffer
            var responses = [NIOIMAP.Response]()
            while originalBufferCopy.readableBytes > 0 {
                responses.append(try self.parser.parseResponseStream(buffer: &originalBufferCopy))
            }

            var roundtripBuffer = context.channel.allocator.buffer(capacity: originalBuffer.readableBytes)
            for response in responses {
                roundtripBuffer.writeResponse(response)
            }

            let originalString = originalBuffer.readString(length: originalBuffer.readableBytes)!
            let roundtripString = roundtripBuffer.readString(length: roundtripBuffer.readableBytes)!
            if originalString != roundtripString {
                self.logger.warning("Input response vs roundtrip output is different")
                self.logger.warning("Response (original):\n\(originalString)")
                self.logger.warning("Response (roundtrip):\n\(roundtripString)")
            } else {
                self.logger.info("\(originalString)")
            }

            context.fireChannelRead(self.wrapInboundOut(roundtripBuffer))
        } catch {
            context.fireErrorCaught(error)
        }
    }
}
