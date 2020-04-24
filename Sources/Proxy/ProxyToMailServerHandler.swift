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
import NIOIMAP
import NIOIMAPCore

class ProxyToMailServerHandler: ChannelInboundHandler {
    typealias InboundIn = NIOIMAP.Response

    let mailAppToProxyChannel: Channel
    var parser = NIOIMAP.ResponseParser()

    init(mailAppToProxyChannel: Channel) {
        self.mailAppToProxyChannel = mailAppToProxyChannel
    }

    func channelActive(context: ChannelHandlerContext) {
        self.mailAppToProxyChannel.closeFuture.whenSuccess {
            context.close(promise: nil)
        }
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let stream = self.unwrapInboundIn(data)
        var buffer = context.channel.allocator.buffer(capacity: 1024)
        buffer.writeResponse(stream)
        self.mailAppToProxyChannel.writeAndFlush(buffer, promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("ERROR: \(error)")
        context.channel.close(promise: nil)
        context.fireErrorCaught(error)
    }
}
