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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Logging
import NIOIMAP

extension IMAPConnection {
    /// Configuration for an IMAP server connection.
    public struct Configuration: Equatable, Sendable {
        /// The server endpoint to connect to.
        public var endpoint: Endpoint

        /// The network endpoint for an IMAP server.
        public enum Endpoint: Equatable, Sendable {
            case hostname(String, port: UInt16)
            case unixDomainSocket(path: String)
        }

        /// Whether to use TLS for the connection.
        public var useTLS: Bool

        /// Controls connection-level debug logging.
        public enum Logging: Hashable, Sendable {
            case noLogging
            case logging
        }

        /// The logging mode for the connection.
        public var logging: Logging

        /// The logger used for connection-level diagnostics.
        ///
        /// Lifecycle and per-command diagnostics are emitted at the `.debug` and `.trace`
        /// levels, so they are suppressed by default. Provide a logger configured with a
        /// lower log level to observe them.
        public var logger: Logger

        public init(
            endpoint: Endpoint,
            useTLS: Bool,
            logging: Logging,
            logger: Logger = Logger(label: "com.apple.swift-nio-imap.IMAPConnection")
        ) {
            self.endpoint = endpoint
            self.useTLS = useTLS
            self.logging = logging
            self.logger = logger
        }

        public static func == (lhs: Configuration, rhs: Configuration) -> Bool {
            // `Logger` is not `Equatable`, so it is excluded from the comparison.
            lhs.endpoint == rhs.endpoint
                && lhs.useTLS == rhs.useTLS
                && lhs.logging == rhs.logging
        }
    }
}

extension IMAPConnection.Configuration {
    public init(
        hostname: String,
        port: UInt16,
        useTLS: Bool,
        logging: Logging,
        logger: Logger = Logger(label: "com.apple.swift-nio-imap.IMAPConnection")
    ) {
        self.init(
            endpoint: .hostname(hostname, port: port),
            useTLS: useTLS,
            logging: logging,
            logger: logger
        )
    }
}

extension IMAPConnection.Configuration.Endpoint {
    /// The hostname if this endpoint uses a hostname connection, or `nil` for UNIX domain sockets.
    public var hostname: String? {
        switch self {
        case .hostname(let host, port: _): host
        case .unixDomainSocket: nil
        }
    }
}

extension IMAPConnection.Configuration {
    init(
        hostname: String,
        port: UInt16,
        logging: Logging
    ) {
        self.init(
            hostname: hostname,
            port: port,
            useTLS: port == 993,
            logging: logging
        )
    }

    /// Creates a configuration by parsing an RFC 5092 IMAP URL or a hostname with optional port.
    public init(
        serverText: String,
        logging: Logging
    ) throws {
        if let c = Self(hostnameAndPortText: serverText, logging: logging) {
            self = c
            return
        }
        guard let url = URL(string: serverText), let scheme = url.scheme else {
            throw ParseServerTextError(description: "Unable to parse server '\(serverText)'.")
        }
        guard scheme == "imap" else {
            throw ParseServerTextError(description: "Server is invalid or URL is not an IMAP URL '\(serverText)'.")
        }
        guard let hostname = url.host else {
            throw ParseServerTextError(description: "Invalid hostname in IMAP URL '\(serverText)'.")
        }
        if let p = url.port {
            guard let port = UInt16(exactly: p) else {
                throw ParseServerTextError(description: "Invalid port '\(p)' in IMAP URL.")
            }
            self.init(hostname: hostname, port: port, logging: logging)
        } else {
            self.init(hostname: hostname, port: 993, logging: logging)
        }
    }

    private init?(hostnameAndPortText text: String, logging: Logging) {
        let scanner = Scanner(string: text)
        scanner.charactersToBeSkipped = nil
        guard let hostname = scanner.scanHostname() else {
            return nil
        }
        if scanner.isAtEnd {
            self.init(hostname: hostname, port: 993, useTLS: true, logging: logging)
        } else {
            guard
                scanner.scanString(":") != nil,
                let _port = scanner.scanUInt64(),
                let port = UInt16(exactly: _port)
            else { return nil }
            self.init(hostname: hostname, port: port, logging: logging)
        }
    }

    /// An error indicating the server text could not be parsed into a valid configuration.
    public struct ParseServerTextError: Swift.Error {
        public var description: String
    }
}

// MARK: -

extension Scanner {
    fileprivate func scanHostname() -> String? {
        guard let first = scanHostnameLabel() else { return nil }
        var parts: [String] = [first]
        while true {
            guard let next = scanDotAndHostnameLabel() else { break }
            parts.append(next)
        }
        return parts.joined(separator: ".")
    }

    private func scanDotAndHostnameLabel() -> String? {
        let original = currentIndex
        guard
            scanString(".") != nil,
            let label = scanHostnameLabel()
        else {
            currentIndex = original
            return nil
        }
        return label
    }

    private func scanHostnameLabel() -> String? {
        let original = currentIndex
        guard
            let s = scanCharacters(from: .hostnameLabel),
            !s.hasPrefix("-"),
            !s.hasSuffix("-")
        else {
            currentIndex = original
            return nil
        }
        return s
    }
}

extension CharacterSet {
    static let hostnameLabel = CharacterSet(
        charactersIn: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-"
    )
}
