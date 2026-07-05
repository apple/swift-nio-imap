//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

/// Proxies a single accepted mail-client connection to the upstream IMAP server.
///
/// A TLS connection to the upstream server is opened, then two pumps run
/// concurrently: one forwarding the client's commands upstream, the other
/// forwarding the server's responses back. When either side closes — or any error
/// is thrown (a bad TLS handshake, a framing/parser error, an unexpected response) —
/// both channels are torn down. Because this all happens inside the connection's own
/// task, such a failure never affects the listening socket or other connections.
func proxyConnection(
    _ clientChannel: NIOAsyncChannel<CommandStreamPart, Response>,
    toServerHost serverHost: String,
    serverPort: Int,
    group: EventLoopGroup
) async throws {
    // Open the upstream, TLS-protected connection. Any failure here (e.g. an invalid
    // TLS configuration or hostname) throws, which closes the client connection.
    let upstreamChannel = try await ClientBootstrap(group: group)
        .connect(host: serverHost, port: serverPort) { channel in
            channel.eventLoop.makeCompletedFuture {
                let sslContext = try NIOSSLContext(configuration: .clientDefault)
                let sslHandler = try NIOSSLClientHandler(context: sslContext, serverHostname: serverHost)
                try channel.pipeline.syncOperations.addHandlers([
                    sslHandler,
                    IMAPClientHandler(),
                ])
                return try NIOAsyncChannel<Response, IMAPClientHandler.Message>(
                    wrappingChannelSynchronously: channel
                )
            }
        }

    try await clientChannel.executeThenClose { clientInbound, clientOutbound in
        try await upstreamChannel.executeThenClose { upstreamInbound, upstreamOutbound in
            try await withThrowingTaskGroup(of: Void.self) { pumps in
                // Client → Server: forward each parsed command upstream.
                pumps.addTask {
                    for try await command in clientInbound {
                        log("CLIENT → SERVER: \(CommandStreamPart.descriptionWithoutPII([command]))")
                        try await upstreamOutbound.write(.part(command))
                    }
                }

                // Server → Client: forward each parsed response back.
                pumps.addTask {
                    for try await response in upstreamInbound {
                        log("SERVER → CLIENT: \(Response.descriptionWithoutPII([response]))")
                        try await clientOutbound.write(response)
                    }
                }

                // As soon as one direction ends (or throws), tear down the other so
                // both channels close together.
                try await pumps.next()
                pumps.cancelAll()
            }
        }
    }
}
