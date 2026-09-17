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

/// Which command to use to authenticate.
enum AuthenticationMethod: Hashable, Sendable {
    /// Use `AUTHENTICATE` when the server advertises the credential’s SASL
    /// mechanism, and fall back to `LOGIN` when it does not.
    case automatic
    /// Always try `LOGIN`, even when the server advertises the mechanism. Fails without
    /// sending anything if the credential has no password, or if the server prohibits `LOGIN`.
    case login
}

extension IMAPConnection {
    /// Authenticates the connection using the given credential.
    func authenticate(
        greeting: IMAPConnection.Greeting,
        credential: IMAPCredential,
        disableSASLIR: Bool,
        method: AuthenticationMethod
    ) async throws -> AuthenticationResult {
        let preAuthCapabilities = try await capabilitiesFromCodeOrSendCommand(
            text: try greeting.status.getOK()
        )
        writeStatus("Pre-auth capabilities: \(preAuthCapabilities.map { String($0) }.sorted().joined(separator: " "))")

        // Authenticate. `AUTHENTICATE` requires the server to advertise the
        // credential’s mechanism; `.login` overrides that and uses `LOGIN`.
        let (mechanism, ir) = credential.makeAuthenticateCommand()
        let useAuthenticate =
            switch method {
            case .automatic: preAuthCapabilities.contains(.authenticate(mechanism))
            case .login: false
            }

        let authResult: TaggedResponse
        if useAuthenticate {
            authResult = try await authenticate(
                saslMechanism: mechanism,
                initialResponse: ir,
                useSASL_IR: !disableSASLIR && preAuthCapabilities.contains(.saslIR)
            )
        } else {
            authResult = try await login(
                credential: credential,
                capabilities: preAuthCapabilities,
                method: method
            )
        }

        let text = try authResult.getOK()
        writeStatus("Did authenticate: \(text.text)")

        let postAuthCapabilities = try await capabilitiesFromCodeOrSendCommand(
            text: text
        )
        writeStatus(
            "Post-auth capabilities: \(postAuthCapabilities.map { String($0) }.sorted().joined(separator: " "))"
        )

        return AuthenticationResult(
            responseText: text.text,
            capabilities: postAuthCapabilities
        )
    }

    private func capabilitiesFromCodeOrSendCommand(
        text: ResponseText
    ) async throws -> [Capability] {
        if case .capability(let c) = text.code {
            return c
        }
        // Get them from the server:
        return try await getCapabilities()
    }

    private func getCapabilities() async throws -> [Capability] {
        try await send(.capability) { tag, responses in
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

    /// Sends `LOGIN`, or throws if either the credential or the server rules it out.
    ///
    /// The credential is checked first: when it can’t produce a `LOGIN` at all, saying so is
    /// more useful than pointing at `LOGINDISABLED` for a command the user never asked for.
    private func login(
        credential: IMAPCredential,
        capabilities: [Capability],
        method: AuthenticationMethod
    ) async throws -> TaggedResponse {
        guard let loginCommand = credential.makeLoginCommand() else {
            switch method {
            case .login:
                throw AuthenticationError(
                    message: "The given credential can only be used with AUTHENTICATE, not LOGIN."
                )
            case .automatic:
                throw AuthenticationError(
                    message:
                        "Server capabilities do not support the available credentials. Capabilities: \(capabilities.map { String($0) }.sorted().joined(separator: " "))"
                )
            }
        }
        guard !capabilities.contains(.loginDisabled) else {
            throw AuthenticationError(
                message: "The server advertises LOGINDISABLED, which prohibits the LOGIN command."
            )
        }
        return try await send(loginCommand) { tag, responses in
            writeStatus("Did send LOGIN command \(tag)")
            return try await responses.waitForCompletion()
        }
    }

    private func authenticate(
        saslMechanism mechanism: AuthenticationMechanism,
        initialResponse ir: InitialResponse,
        useSASL_IR supportsIR: Bool
    ) async throws -> TaggedResponse {
        try await sendAuthenticate(
            mechanism: mechanism,
            initialResponse: supportsIR ? ir : nil
        ) { tag, responses, writer in
            writeStatus(
                "Did send AUTHENTICATE \(String(mechanism)) command \(tag) \(supportsIR ? "with" : "without") IR"
            )
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
            mechanism = m
            data = response
        }
        return (mechanism, InitialResponse(ByteBuffer(data)))
    }

    func makeLoginCommand() -> Command? {
        guard case .username(let u, password: let p) = self else { return nil }
        return .login(username: u, password: p)
    }
}
