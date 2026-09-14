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

import ArgumentParser
import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

struct IdentifyCommand: AsyncParsableCommand, Sendable {
    static let configuration = CommandConfiguration(
        commandName: "id",
        abstract: "Identify the server"
    )

    @OptionGroup()
    var connectionInfo: ConnectionInfo

    @Option(help: "How to format the result.")
    var outputFormat: ResultFormat = .text

    func run() async throws {
        let config = try connectionInfo.makeConfiguration()

        let result = try await IMAPConnection.withConnection(configuration: config) { greeting, connection in
            writeStatus("Server greeting: \(greeting.status)")
            let r = try await authenticate(
                connection: connection,
                greeting: greeting,
                connectionInfo: connectionInfo
            )
            return try await identify(
                connection: connection,
                capabilities: r.capabilities
            )
        }

        writeResult(result: result, format: outputFormat)
    }
}

/// Authenticates the connection using the credentials from `connectionInfo`.
func authenticate(
    connection: IMAPConnection,
    greeting: IMAPConnection.Greeting,
    connectionInfo: ConnectionInfo
) async throws -> AuthenticationResult {
    try await authenticate(
        connection: connection,
        greeting: greeting,
        credential: try connectionInfo.makeCredential(),
        disableSASLIR: connectionInfo.disableSASLIR,
        forceLogin: connectionInfo.forceLogin
    )
}

extension IMAPConnection {
    /// Runs the given closure with an authenticated IMAP connection.
    static func withAuthenticatedConnection<Result: Sendable>(
        info connectionInfo: ConnectionInfo,
        _ body: @Sendable @escaping (Identity, IMAPConnection) async throws -> Result
    ) async throws -> Result {
        let config = try connectionInfo.makeConfiguration()

        return try await IMAPConnection.withConnection(configuration: config) { greeting, connection in
            writeStatus("Connected to \(config.endpoint.hostname ?? ""), received greeting: '\(greeting.status)'")
            let r = try await authenticate(
                connection: connection,
                greeting: greeting,
                connectionInfo: connectionInfo
            )
            let identity = try await identify(
                connection: connection,
                capabilities: r.capabilities
            )

            defer {
                writeStatus("Closing connection to server.")
            }
            return try await body(identity, connection)
        }
    }
}
