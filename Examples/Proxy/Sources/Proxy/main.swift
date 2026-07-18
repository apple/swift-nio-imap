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
import NIOSSL

/// Logs a single line of proxy output.
///
/// Callers are responsible for redacting personally identifiable information
/// (PII) before calling this — see `CommandStreamPart.descriptionWithoutPII(_:)`
/// and `Response.descriptionWithoutPII(_:)`.
func log(_ message: String) {
    print(message)
}

// MARK: - Configuration

guard CommandLine.arguments.count == 5 else {
    print("Usage: Proxy <bind-host> <bind-port> <server-host> <server-port>")
    exit(1)
}

let host = CommandLine.arguments[1]
guard let port = Int(CommandLine.arguments[2]), (1...65535).contains(port) else {
    print("Invalid bind port: must be an integer in the range 1–65535")
    exit(1)
}

let serverHost = CommandLine.arguments[3]
guard let serverPort = Int(CommandLine.arguments[4]), (1...65535).contains(serverPort) else {
    print("Invalid server port: must be an integer in the range 1–65535")
    exit(1)
}

// MARK: - Run

// A single event loop keeps the example simple and its log output easy to follow. A
// production proxy would size this to the available cores (e.g. `System.coreCount`) or
// use the shared `MultiThreadedEventLoopGroup.singleton`.
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

// The listening socket. Each accepted mail-client connection is surfaced as its own
// `NIOAsyncChannel` that decodes the client's commands (`CommandStreamPart`) and
// encodes our responses (`Response`).
//
// Warning: the client-facing side is plaintext — there is no TLS on this listener, so
// the mail client's credentials cross the client → proxy hop in the clear. Only bind
// this to a loopback address (`127.0.0.1` / `::1`). See README.md.
let serverChannel = try await ServerBootstrap(group: eventLoopGroup)
    // Allow the proxy to rebind its port immediately after a restart.
    .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
    .bind(host: host, port: port) { channel in
        channel.eventLoop.makeCompletedFuture {
            try channel.pipeline.syncOperations.addHandlers([
                ByteToMessageHandler(FrameDecoder()),
                IMAPServerHandler(),
            ])
            return try NIOAsyncChannel<CommandStreamPart, Response>(wrappingChannelSynchronously: channel)
        }
    }

log("Proxy listening on \(host):\(port), forwarding to \(serverHost):\(serverPort)")

// Accept connections forever. Each client runs in its own child task, so a failure on
// one connection — a malformed command, a broken TLS handshake, a parser error — only
// tears down that connection and never the whole proxy.
//
// Note: there is no cap on the number of concurrent connections and no idle/handshake
// timeout, so this example is not hardened against resource exhaustion — see README.md.
try await withThrowingDiscardingTaskGroup { taskGroup in
    try await serverChannel.executeThenClose { inbound in
        for try await clientChannel in inbound {
            taskGroup.addTask {
                do {
                    try await proxyConnection(
                        clientChannel,
                        toServerHost: serverHost,
                        serverPort: serverPort,
                        group: eventLoopGroup
                    )
                } catch {
                    log("Connection closed with error: \(error)")
                }
            }
        }
    }
}

// Reached only once the listening socket closes and every connection has finished.
try await eventLoopGroup.shutdownGracefully()
