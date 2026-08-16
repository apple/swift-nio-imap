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
            /// Does not trace channel events.
            case noLogging
            /// Traces every channel event to the task-local logger at the `.trace` level.
            ///
            /// - Warning: The traces include the data read and written, so they carry message
            ///   content and the commands sent to the server — including credentials. This is
            ///   for local debugging; do not enable it where the log stream is collected or
            ///   shipped off the device.
            case logging
        }

        /// The logging mode for the connection.
        ///
        /// This only controls the low-level channel-event tracing described by ``Logging``. It is
        /// independent of the connection's own lifecycle diagnostics, which are always emitted to
        /// the task-local logger at `.debug` and `.trace`.
        public var logging: Logging

        public init(
            endpoint: Endpoint,
            useTLS: Bool,
            logging: Logging
        ) {
            self.endpoint = endpoint
            self.useTLS = useTLS
            self.logging = logging
        }
    }
}

extension IMAPConnection.Configuration {
    public init(
        hostname: String,
        port: UInt16,
        useTLS: Bool,
        logging: Logging
    ) {
        self.init(
            endpoint: .hostname(hostname, port: port),
            useTLS: useTLS,
            logging: logging
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

    /// Creates a configuration from a hostname with an optional `:port` suffix.
    ///
    /// Returns `nil` if the text is not a hostname (optionally followed by a port), in which
    /// case ``init(serverText:logging:)`` falls back to parsing the text as an IMAP URL.
    private init?(hostnameAndPortText text: String, logging: Logging) {
        if let colon = text.firstIndex(of: ":") {
            let hostname = text[..<colon]
            guard
                Self.isValidHostname(hostname),
                let portNumber = UInt64(text[text.index(after: colon)...]),
                let port = UInt16(exactly: portNumber)
            else { return nil }
            self.init(hostname: String(hostname), port: port, logging: logging)
        } else {
            guard Self.isValidHostname(text) else { return nil }
            self.init(hostname: text, port: 993, useTLS: true, logging: logging)
        }
    }

    /// Whether the text is a non-empty, dot-separated list of valid hostname labels.
    private static func isValidHostname(_ text: some StringProtocol) -> Bool {
        guard !text.isEmpty else { return false }
        return text.split(separator: ".", omittingEmptySubsequences: false)
            .allSatisfy { isValidHostnameLabel($0) }
    }

    /// Whether the text is a valid hostname label, i.e. non-empty, made up of ASCII letters,
    /// digits, and hyphens, and neither starting nor ending with a hyphen.
    private static func isValidHostnameLabel(_ label: some StringProtocol) -> Bool {
        guard
            !label.isEmpty,
            label.utf8.allSatisfy({ $0.isHostnameLabelByte })
        else { return false }
        return (label.first != "-") && (label.last != "-")
    }

    /// An error indicating the server text could not be parsed into a valid configuration.
    public struct ParseServerTextError: Swift.Error {
        public var description: String
    }
}

// MARK: -

extension UInt8 {
    /// Whether this is an ASCII letter, digit, or hyphen.
    fileprivate var isHostnameLabelByte: Bool {
        switch self {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): true
        case UInt8(ascii: "A")...UInt8(ascii: "Z"): true
        case UInt8(ascii: "a")...UInt8(ascii: "z"): true
        case UInt8(ascii: "-"): true
        default: false
        }
    }
}
