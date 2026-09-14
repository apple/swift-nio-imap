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
import Synchronization
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Command-line arguments for establishing an IMAP connection and authenticating.
public struct ConnectionInfo: ParsableArguments, Sendable {
    public init() {}

    init(
        server: String? = nil,
        sasl: String? = nil,
        disableSASLIR: Bool = false,
        forceLogin: Bool = false,
        username: String? = nil,
    ) {
        self.server = server
        self.sasl = sasl
        self.disableSASLIR = disableSASLIR
        self.forceLogin = forceLogin
        self.username = username
    }

    @Option(help: "The server to connect to.")
    var server: String?

    @Option(help: "Use SASL to authenticate (for example, 'plain:foobar').")
    var sasl: String?

    @Flag(name: .customLong("disable-sasl-ir"), help: "Disable the use of SASL-IR (RFC 4959).")
    var disableSASLIR: Bool = false

    @Flag(help: "Force use of LOGIN (instead of AUTH PLAIN).")
    var forceLogin: Bool = false

    @Option(help: ArgumentHelp("Use LOGIN or AUTH PLAIN to authenticate.", valueName: "user:password"))
    var username: String?

    /// An opaque account identifier resolved by the embedding tool.
    ///
    /// `IMAPToolLib` itself does not know how to resolve accounts. An embedder
    /// can install an ``ConnectionInfo/accountResolver`` that maps this
    /// identifier to a connection configuration and credential (for example,
    /// by looking it up in the system's account store). When no resolver is
    /// installed this option is inert.
    @Option(
        help: ArgumentHelp(
            "An account identifier resolved by the embedding tool.",
            visibility: .private
        )
    )
    var account: String?

    @Flag(
        name: .customLong("connection-logging"),
        help: ArgumentHelp(
            "Log connection (debug) activity.",
            visibility: .private
        )
    )
    var _connectionLogging: Bool = false

    var connectionLogging: IMAPConnection.Configuration.Logging {
        _connectionLogging ? .logging : .noLogging
    }

    public mutating func validate() throws {
        _ = try self.makeConfiguration()
    }

    /// The resolved connection endpoint and credential for an account identifier.
    ///
    /// Only the connection endpoint is provided here; the `logging` setting is
    /// applied by ``ConnectionInfo`` itself so that `--connection-logging` keeps
    /// working for account-based connections.
    public struct ResolvedAccount: Sendable {
        public var hostname: String
        public var port: UInt16
        public var useTLS: Bool
        public var credential: IMAPCredential

        public init(hostname: String, port: UInt16, useTLS: Bool, credential: IMAPCredential) {
            self.hostname = hostname
            self.port = port
            self.useTLS = useTLS
            self.credential = credential
        }
    }

    /// A closure that resolves an account identifier (see ``ConnectionInfo/account``)
    /// into a connection endpoint and credential, or returns `nil` if the
    /// identifier is unknown.
    public typealias AccountResolver = @Sendable (_ identifier: String) throws -> ResolvedAccount?

    private static let _accountResolver = Mutex<AccountResolver?>(nil)

    /// Installs a resolver used to turn an ``ConnectionInfo/account`` identifier into a
    /// connection endpoint and credential. Passing `nil` removes any installed resolver.
    ///
    /// This is the seam an embedding tool uses to support account-based authentication
    /// (for example, tokens sourced from the system account store) without `IMAPToolLib`
    /// having to know anything about where those accounts come from.
    public static func setAccountResolver(_ resolver: AccountResolver?) {
        _accountResolver.withLock { $0 = resolver }
    }

    private func resolveAccount() throws -> ResolvedAccount? {
        guard let account else { return nil }
        guard let resolver = Self._accountResolver.withLock({ $0 }) else {
            throw ValidationError("No account resolver is installed for '--account \(account)'.")
        }
        guard let resolved = try resolver(account) else {
            throw ValidationError("Unknown account '\(account)'.")
        }
        return resolved
    }

    /// Creates a ``IMAPConnection.Configuration`` from the parsed server argument.
    func makeConfiguration() throws -> IMAPConnection.Configuration {
        if let resolved = try resolveAccount() {
            return IMAPConnection.Configuration(
                hostname: resolved.hostname,
                port: resolved.port,
                useTLS: resolved.useTLS,
                logging: connectionLogging
            )
        }
        guard let text = server else {
            throw ValidationError("Need to specify either a server name or an account.")
        }
        do {
            return try IMAPConnection.Configuration(
                serverText: text,
                logging: connectionLogging
            )
        } catch let e as IMAPConnection.Configuration.ParseServerTextError {
            throw ValidationError(e.description)
        }
    }

    /// Creates a ``IMAPCredential`` from the parsed authentication arguments.
    func makeCredential() throws -> IMAPCredential {
        if let resolved = try resolveAccount() {
            return resolved.credential
        }
        return try IMAPCredential(url: self.server, sasl: self.sasl, username: self.username)
    }
}
