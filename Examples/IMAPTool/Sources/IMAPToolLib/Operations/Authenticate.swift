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

import IMAPCommands
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import NIO
import NIOIMAP

/// The result of a successful IMAP authentication.
struct AuthenticationResult: Hashable, Sendable {
    var responseText: String
    var capabilities: [Capability]
}

/// Authenticates the connection using the given credential.
func authenticate(
    connection: IMAPConnection,
    greeting: IMAPConnection.Greeting,
    credential: IMAPCredential,
    disableSASLIR: Bool,
    forceLogin: Bool
) async throws -> AuthenticationResult {
    let preAuthCapabilities = try await capabilitiesFromCodeOrSendCommand(
        connection: connection,
        text: try greeting.status.getOK()
    )
    writeStatus("Pre-auth capabilities: \(preAuthCapabilities.map { String($0) }.sorted().joined(separator: " "))")

    // Authenticate:
    let authResult: TaggedResponse
    let (mechanism, ir) = credential.makeAuthenticateCommand()
    if preAuthCapabilities.contains(.authenticate(mechanism)) {
        authResult = try await authenticate(
            connection: connection,
            saslMechanism: mechanism,
            initialResponse: ir,
            useSASL_IR: !disableSASLIR && preAuthCapabilities.contains(.saslIR)
        )
    } else if let login = credential.makeLoginCommand() {
        authResult = try await connection.send(login) { tag, responses in
            writeStatus("Did send LOGIN command \(tag)")
            return try await responses.waitForCompletion()
        }
    } else {
        throw AuthenticationError(
            message:
                "Server capabilities do not support the available credentials. Capabilities: \(preAuthCapabilities.map { String($0) }.sorted().joined(separator: " "))"
        )
    }
    let text = try authResult.getOK()
    writeStatus("Did authenticate: \(text.text)")

    let postAuthCapabilities = try await capabilitiesFromCodeOrSendCommand(
        connection: connection,
        text: text
    )
    writeStatus("Post-auth capabilities: \(postAuthCapabilities.map { String($0) }.sorted().joined(separator: " "))")

    return AuthenticationResult(
        responseText: text.text,
        capabilities: postAuthCapabilities
    )
}

private func capabilitiesFromCodeOrSendCommand(
    connection: IMAPConnection,
    text: ResponseText
) async throws -> [Capability] {
    if case .capability(let c) = text.code {
        return c
    }
    // Get them from the server:
    return try await getCapabilities(connection: connection)
}

private func getCapabilities(
    connection: IMAPConnection
) async throws -> [Capability] {
    try await connection.send(.capability) { tag, responses in
        var result: [Capability]? = nil
        for try await r in responses {
            switch r {
            case .tagged(let r):
                try r.checkOK()
            case .untagged(.capabilityData(let c)):
                result = c
            default:
                break
            }
        }
        guard
            let result
        else {
            throw AuthenticationError(message: "Server did not return Capabilities")
        }
        return result
    }
}

private func authenticate(
    connection: IMAPConnection,
    saslMechanism mechanism: AuthenticationMechanism,
    initialResponse ir: InitialResponse,
    useSASL_IR supportsIR: Bool
) async throws -> TaggedResponse {
    try await connection.sendAuthenticate(
        mechanism: mechanism,
        initialResponse: supportsIR ? ir : nil
    ) { tag, responses, writer in
        writeStatus("Did send AUTHENTICATE \(mechanism.rawValue) command \(tag) \(supportsIR ? "with" : "without") IR")
        return try await responses.forEach { response in
            switch response {
            case .authenticationChallenge:
                guard !supportsIR else {
                    throw AuthenticationError(message: "Unexpected challenge.")
                }
                try await writer.writeContinuation(ir.data)
            default:
                return
            }
        }
    }
}

struct AuthenticationError: Equatable, Swift.Error {
    var message: String
}

// MARK: -

extension ResponsePayload {
    var capabilities: [Capability]? {
        if case .conditionalState(.ok(let s)) = self, case .capability(let c)? = s.code {
            return c
        } else if case .capabilityData(let c) = self {
            return c
        }
        return nil
    }
}

extension IMAPCredential {
    func makeAuthenticateCommand() -> (AuthenticationMechanism, InitialResponse) {
        let mechanism: AuthenticationMechanism
        let data: Data
        switch self {
        case .username(let u, password: let p):
            mechanism = .plain
            data = Data([0]) + Data(u.utf8) + Data([0]) + Data(p.utf8)
        case .sasl(mechanism: let m, response: let response):
            mechanism = AuthenticationMechanism(m)
            data = response
        }
        return (mechanism, InitialResponse(ByteBuffer(data)))
    }

    func makeLoginCommand() -> Command? {
        guard case .username(let u, password: let p) = self else { return nil }
        return .login(username: u, password: p)
    }
}
