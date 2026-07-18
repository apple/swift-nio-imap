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
import NIOSSL

/// Proxies a single accepted mail-client connection to the upstream IMAP server.
///
/// The accepted client connection is drained first; inside it a TLS connection to the
/// upstream server is opened, then two pumps run concurrently: one forwarding the
/// client's commands upstream, the other forwarding the server's responses back. When
/// either side closes — or any error is thrown (a bad TLS handshake, a framing/parser
/// error, an unexpected response) — both channels are torn down together.
///
/// This function propagates any such failure to its caller. `main.swift` runs each
/// connection in its own task and logs the error there, so one failed connection never
/// affects the listening socket or any other connection.
///
/// - Note: `serverHost` must be a DNS hostname that matches the upstream server's TLS
///   certificate. An IP address will fail SNI / hostname verification and the
///   connection will be rejected.
func proxyConnection(
    _ clientChannel: NIOAsyncChannel<CommandStreamPart, Response>,
    toServerHost serverHost: String,
    serverPort: Int,
    group: EventLoopGroup
) async throws {
    // Drain the client connection first. Opening the upstream connection *inside* this
    // `executeThenClose` guarantees the accepted client connection is always closed,
    // even if the upstream connect below fails (e.g. an invalid TLS configuration, an
    // unreachable server, or an IP address passed as `serverHost`).
    try await clientChannel.executeThenClose { clientInbound, clientOutbound in
        // Open the upstream, TLS-protected connection.
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

                // As soon as one direction ends (or throws), tear down the other so both
                // channels close together. If the first pump to finish threw a real
                // error, `next()` rethrows it here and the task group cancels the
                // remaining pump for us. Otherwise one direction reached end-of-stream
                // cleanly, so we cancel the survivor; cancelling a pump suspended in a
                // read or write surfaces as a `CancellationError`, which is the normal
                // end-of-connection path and is swallowed rather than reported.
                try await pumps.next()
                pumps.cancelAll()
                do {
                    for try await _ in pumps {}
                } catch is CancellationError {
                    // Expected: the surviving pump was cancelled during teardown.
                }
            }
        }
    }
}
