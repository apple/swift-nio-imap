//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
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

struct ClientFrameDecoder: ByteToMessageDecoder {
    
    typealias InboundOut = ByteBuffer
    
    var framingParser = ClientFramingParser()
    
    mutating func decode(context: ChannelHandlerContext, buffer: inout ByteBuffer) throws -> DecodingState {
        let frames = self.framingParser.appendAndFrameBuffer(&buffer)
        guard frames.count > 0 else {
            return .needMoreData
        }
        
        for frame in frames {
            context.fireChannelRead(self.wrapInboundOut(frame))
        }
        return .continue
    }
    
}
