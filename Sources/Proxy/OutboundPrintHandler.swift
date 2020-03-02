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

class OutboundPrintHandler: ChannelOutboundHandler {
    
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = ByteBuffer
    
    let type: String
    
    init(type: String) {
        self.type = type
    }
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        var buffer = self.unwrapOutboundIn(data)
        let string = buffer.readString(length: buffer.readableBytes)!
        print("\(type):\n\(string)")
        context.write(data, promise: promise)
    }
    
}
