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
import NIOSSL

class MailClientToProxyHandler: ChannelInboundHandler {
    typealias InboundIn = CommandStreamPart

    var parser = CommandParser()
    var clientChannel: Channel?

    let serverHost: String
    let serverPort: Int

    init(serverHost: String, serverPort: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
    }

    func channelActive(context: ChannelHandlerContext) {
        let mailClientToProxyChannel = context.channel
        let serverHost = self.serverHost
        let boundContext = NIOLoopBound(context, eventLoop: context.eventLoop)
        let boundSelf = NIOLoopBound(self, eventLoop: context.eventLoop)
        ClientBootstrap(group: context.eventLoop).channelInitializer { channel in
            let sslHandler = try! NIOSSLClientHandler(context: NIOSSLContext(configuration: .clientDefault), serverHostname: serverHost)
            return channel.pipeline.addHandlers([
                sslHandler,
                OutboundPrintHandler(type: "CLIENT (Encoded)"),
                InboundPrintHandler(type: "SERVER (Original)"),
                IMAPClientHandler(encodingChangeCallback: { _, _ in }),
                ProxyToMailServerHandler(mailAppToProxyChannel: mailClientToProxyChannel),
            ])
        }.connect(host: serverHost, port: self.serverPort).map { channel in
            boundSelf.value.clientChannel = channel
            channel.closeFuture.whenSuccess {
                boundContext.value.close(promise: nil)
            }
        }.whenFailure { error in
            print("CONNECT ERROR: \(error)")
            boundContext.value.close(promise: nil)
        }

        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let command = self.unwrapInboundIn(data)
        self.clientChannel?.writeAndFlush(command, promise: nil)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if let error = error as? IMAPDecoderError {
            print("CLIENT ERROR: \(error.parserError)")
            print("CLIENT: \(String(decoding: error.buffer.readableBytesView, as: Unicode.UTF8.self))")
        } else {
            print("CLIENT ERROR: \(error)")
        }
        context.channel.close(promise: nil)
        context.fireErrorCaught(error)
    }
}
