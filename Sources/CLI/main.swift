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

import CLILib
import Logging
import NIO
import NIOIMAP
import NIOSSL

let logger = Logger(label: "swiftnio.cli.main")
logger.info("Welcome to the NIOIMAP CLI demo")
logger.info("Enter an IMAP server hostname (SSL required): ")

guard let hostname = readLine(strippingNewline: true) else {
    logger.critical("Unable to read server hostname")
    exit(1)
}

logger.info("Great! Connecting to \(hostname)")

let sslContext = try NIOSSLContext(configuration: .clientDefault)
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let channel = try ClientBootstrap(group: group).channelInitializer { (channel) -> EventLoopFuture<Void> in
    channel.pipeline.addHandlers([
        try! NIOSSLClientHandler(context: sslContext, serverHostname: hostname),
        ResponseRoundtripHandler(logger: logger),
        CommandRoundtripHandler(logger: logger),
    ])
}.connect(host: hostname, port: 993).wait()

_ = channel.closeFuture.always { result in
    switch result {
    case .failure(let error):
        logger.error("Channel closed with error \(error)")
        exit(1)
    case .success():
        logger.info("Channel closed")
        exit(0)
    }
}

logger.info("Connected to \(hostname)")
logger.info("Waiting for commands...")

while true {
    guard let strCommand = readLine(strippingNewline: true) else {
        logger.info("ERROR: Invalid line")
        continue
    }
    var buffer = channel.allocator.buffer(capacity: strCommand.utf8.count)
    buffer.writeString(strCommand + "\r\n")

    // handle the error somewhat gracefully
    do {
        try channel.writeAndFlush(buffer).wait()
    } catch {
        logger.error("Error writing command: \(error)")
    }
}
