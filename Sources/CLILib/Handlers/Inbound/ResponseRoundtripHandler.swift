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

//    let processor = NIOSingleStepByteToMessageProcessor(ResponseDecoder())
    let logger: Logger
    private var parser = ResponseParser()

    public var capabilities: EncodingCapabilities = []

    public init(logger: Logger) {
        self.logger = logger
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//        var buffer = self.unwrapInboundIn(data)
//        let originalString = String(buffer: buffer)
//
//        var responses = [ResponseOrContinueRequest]()
//        do {
//            try self.processor.process(buffer: buffer) { (response) in
//                responses.append(response)
//            }
//        } catch {
//            self.logger.error("Response parsing error: \(error)")
//            self.logger.error("Response: \(originalString)")
//            context.fireErrorCaught(error)
//            return
//        }
//
//        buffer.clear()
//        var encodeBuffer = ResponseEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
//        for response in responses {
//            switch response {
//            case .response(let response):
//                encodeBuffer.writeResponse(response)
//            case .continueRequest(let req):
//                encodeBuffer.writeContinueRequest(req)
//            }
//        }
//
//        let roundtripString = String(buffer: encodeBuffer.bytes)
//        if originalString != roundtripString {
//            self.logger.warning("Input response vs roundtrip output is different")
//            self.logger.warning("Response (original):\n\(originalString)")
//            self.logger.warning("Response (roundtrip):\n\(roundtripString)")
//        } else {
//            self.logger.info("\(originalString)")
//        }
//
//        context.fireChannelRead(self.wrapInboundOut(buffer))
    }
}
