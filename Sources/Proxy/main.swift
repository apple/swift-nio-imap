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

import Foundation
import NIO
import NIOIMAP
import NIOIMAPCore
import NIOSSL

func log(_ string: String, buffer: ByteBuffer? = nil) {
    if let buffer = buffer {
        print(string, String(decoding: buffer.readableBytesView, as: Unicode.UTF8.self))
    } else {
        print(string)
    }
}

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
defer {
    try! eventLoopGroup.syncShutdownGracefully()
}

// MARK: - Configuration

guard CommandLine.arguments.count == 5 else {
    print("Run the command using <localhost> <localport> <serverhost> <serverport>")
    exit(1)
}

let host = CommandLine.arguments[1]
guard let port = Int(CommandLine.arguments[2]) else {
    print("Invalid port, couldn't convert to an integer")
    exit(1)
}

let serverHost = CommandLine.arguments[3]
guard let serverPort = Int(CommandLine.arguments[4]) else {
    print("Invalid server port, couldn't convert to an integer")
    exit(1)
}

// MARK: - Run

try ServerBootstrap(group: eventLoopGroup)
    .childChannelInitializer { channel -> EventLoopFuture<Void> in
        channel.eventLoop.makeCompletedFuture {
            try! channel.pipeline.syncOperations.addHandlers([
                InboundPrintHandler(type: "CLIENT (Original)"),
                OutboundPrintHandler(type: "SERVER (Decoded)"),
                ByteToMessageHandler(FrameDecoder()),
                IMAPServerHandler(),
                MailClientToProxyHandler(serverHost: serverHost, serverPort: serverPort),
            ])
        }
    }
    .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    .bind(host: host, port: port).wait()
    .closeFuture.wait()
