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

class MailClientToProxyHandler: ChannelInboundHandler {
    
    typealias InboundIn = NIOIMAP.CommandStream
    
    var parser = NIOIMAP.CommandParser()
    var clientChannel: Channel?
    
    let serverHost: String
    let serverPort: Int
    
    init(serverHost: String, serverPort: Int) {
        self.serverHost = serverHost
        self.serverPort = serverPort
    }
    
    func channelActive(context: ChannelHandlerContext) {
        
        let mailClientToProxyChannel = context.channel
        ClientBootstrap(group: context.eventLoop).channelInitializer { channel in
            let sslHandler = try! NIOSSLClientHandler(context: NIOSSLContext(configuration: .clientDefault), serverHostname: self.serverHost)
            return channel.pipeline.addHandlers([
                sslHandler,
                OutboundPrintHandler(type: "CLIENT (Encoded)"),
                InboundPrintHandler(type: "SERVER (Original)"),
                ByteToMessageHandler(NIOIMAP.ResponseDecoder()),
                MessageToByteHandler(NIOIMAP.CommandEncoder()),
                ProxyToMailServerHandler(mailAppToProxyChannel: mailClientToProxyChannel),
            ])
        }.connect(host: serverHost, port: serverPort).map { channel in
            self.clientChannel = channel
            channel.closeFuture.whenSuccess {
                context.close(promise: nil)
            }
        }.whenFailure { error in
            print("CONNECT ERROR: \(error)")
            context.close(promise: nil)
        }
        
        context.fireChannelActive()
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        self.clientChannel?.writeAndFlush(data, promise: nil)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if let error = error as? NIOIMAP.IMAPDecoderError {
            print("CLIENT ERROR: \(error.parserError)")
            print("CLIENT: \(String(decoding: error.buffer.readableBytesView, as: Unicode.UTF8.self))")
        } else {
            print("CLIENT ERROR: \(error)")
        }
        context.channel.close(promise: nil)
        context.fireErrorCaught(error)
    }
    
}
