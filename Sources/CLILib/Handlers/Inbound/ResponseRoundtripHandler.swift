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

    let processor = NIOSingleStepByteToMessageProcessor(ResponseDecoder())
    let logger: Logger
    private var parser = ResponseParser()

    public init(logger: Logger) {
        self.logger = logger
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var originalBuffer = self.unwrapInboundIn(data)
        var responses = [ResponseOrContinueRequest]()
        do {
            try processor.process(buffer: originalBuffer, { (response) in
                responses.append(response)
            })
        } catch {
            self.logger.error("Response parsing error: \(error)")
            self.logger.error("Response: \(String(buffer: originalBuffer))")
            context.fireErrorCaught(error)
            return
        }

        var roundtripBuffer = context.channel.allocator.buffer(capacity: originalBuffer.readableBytes)
        for response in responses {
            switch response {
            case .response(let response):
                roundtripBuffer.writeResponse(response)
            case .continueRequest(let cReq):
                roundtripBuffer.writeContinueRequest(cReq)
            }
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
    }
}
