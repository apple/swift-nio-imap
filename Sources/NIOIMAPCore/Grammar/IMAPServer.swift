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

import struct NIO.ByteBuffer

/// Server connection information for an IMAP URL, including optional user and authentication details.
///
/// The server component of an IMAP URL specifies how to connect to the IMAP server.
/// It includes the host and optional port, plus optional user and authentication mechanism information.
/// IMAP URLs use this in the format `imap://[userauth@]host[:port]/...` (RFC 2192, extended by RFC 4467).
///
/// ### Components
///
/// - **Host**: A registered name, IPv4 address, or bracketed IP literal (see ``Host``)
/// - **Port**: Optional TCP port number (defaults to 143 for IMAP or 993 for IMAPS if not specified)
/// - **User Authentication**: Optional user identifier and/or authentication mechanism requirement
///
/// ### Examples
///
/// Basic server with hostname only:
/// ```
/// imap://example.com/INBOX/;uid=20
/// ```
///
/// Server with optional port:
/// ```
/// imap://example.com:993/INBOX/;uid=20
/// ```
///
/// Server with user (used for mailbox context):
/// ```
/// imap://user@example.com/INBOX/;uid=20
/// ```
///
/// Server with authentication mechanism requirement:
/// ```
/// imap://;AUTH=PLAIN@example.com/INBOX/;uid=20
/// ```
///
/// In GENURLAUTH commands, the server component identifies the owner of the mailbox access key table
/// that will be used to generate or verify the URLAUTH token:
/// ```
/// C: a001 GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=user+fred" INTERNAL
/// S: * GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=user+fred:internal:..."
/// ```
///
/// ## Related types
///
/// See ``UserAuthenticationMechanism`` for the optional user and authentication specification,
/// ``IMAPURLAuthenticationMechanism`` for authentication mechanism constraints, and
/// ``IMAPURL`` for the complete URL structure.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4467 Section 5](https://datatracker.ietf.org/doc/html/rfc4467#section-5) - Generation of URLAUTH-Authorized URLs
public struct IMAPServer: Hashable, Sendable {
    /// Optional user identification and authentication mechanism requirement.
    ///
    /// When specified, this indicates either a specific user context for mailbox resolution or
    /// a required authentication mechanism. For GENURLAUTH commands, this typically specifies
    /// the owner of the mailbox access key table.
    public var userAuthenticationMechanism: UserAuthenticationMechanism?

    /// The host name or IP address of the IMAP server.
    public var host: Host

    /// Optional TCP port number for the IMAP service.
    ///
    /// If not specified, the default IMAP port (143) or secure IMAP port (993) should be used
    /// based on the connection security settings.
    public var port: UInt16?

    /// Creates a new IMAP server connection specification.
    /// - parameter userAuthenticationMechanism: Optional user and/or authentication mechanism. Defaults to `nil`.
    /// - parameter host: The host name or IP address of the server.
    /// - parameter port: Optional TCP port number. Defaults to `nil`.
    public init(userAuthenticationMechanism: UserAuthenticationMechanism? = nil, host: Host, port: UInt16? = nil) {
        self.userAuthenticationMechanism = userAuthenticationMechanism
        self.host = host
        self.port = port
    }
}

extension IMAPServer {
    /// The host of an IMAP URL: a registered name such as `imap.example.com`, an IPv4 address such
    /// as `192.0.2.1`, or an IP literal in brackets such as `[2001:db8::1]`.
    ///
    /// ## Validity
    ///
    /// A host is written to the wire verbatim, so anything that isn't an RFC 3986 `host` is
    /// rejected:
    ///
    /// - ``init(_:)`` returns `nil`. Use it for a host derived from input.
    /// - ``init(stringLiteral:)`` traps. A literal is written by the programmer, so an invalid one
    ///   is a bug to be caught on first run rather than handled.
    ///
    /// Hosts compare case-insensitively, so `"Example.COM" == "example.com"` and
    /// `"[2001:DB8::1]" == "[2001:db8::1]"`
    /// ([RFC 3986 Section 3.2.2](https://datatracker.ietf.org/doc/html/rfc3986#section-3.2.2)).
    /// The original case is kept and written to the wire.
    ///
    /// - SeeAlso: [RFC 3986 Section 3.2.2](https://datatracker.ietf.org/doc/html/rfc3986#section-3.2.2)
    public struct Host: Hashable, Sendable {
        let stringValue: String

        /// Creates a host from a string, if the string is a valid RFC 3986 `host`.
        ///
        /// Hex digits in `pct-encoded` triplets of a registered name are uppercased, for example
        /// `%c3` becomes `%C3`. An IP literal keeps its brackets.
        ///
        /// A string literal resolves to ``init(stringLiteral:)`` instead, which traps rather than
        /// returning `nil`.
        ///
        /// - parameter stringValue: The host, for example `imap.example.com` or `[::1]`.
        /// - returns: A new host, or `nil` if `stringValue` is not a valid `host`.
        public init?(_ stringValue: String) {
            guard let normalized = Self.normalized(stringValue) else { return nil }
            self.stringValue = normalized
        }

        init(unchecked stringValue: String) {
            assert(Self.normalized(stringValue) == stringValue)
            self.stringValue = stringValue
        }

        /// Compares case-insensitively.
        ///
        /// Valid values are ASCII, so `uppercased()` is ASCII case-folding.
        public static func == (lhs: Host, rhs: Host) -> Bool {
            lhs.stringValue.uppercased() == rhs.stringValue.uppercased()
        }

        /// Hashes the case-folded value, consistent with `==`.
        public func hash(into hasher: inout Hasher) {
            self.stringValue.uppercased().hash(into: &hasher)
        }

        /// The given string with uppercased `pct-encoded` hex digits, if it is a `host`
        /// ([RFC 3986 Section 3.2.2](https://datatracker.ietf.org/doc/html/rfc3986#section-3.2.2)):
        /// ```
        /// host        = IP-literal / IPv4address / reg-name
        /// IP-literal  = "[" ( IPv6address / IPvFuture  ) "]"
        /// IPvFuture   = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
        /// reg-name    = *( unreserved / pct-encoded / sub-delims )
        /// ```
        /// Every `IPv4address` is also a `reg-name`, so it needs no check of its own.
        static func normalized(_ string: String) -> String? {
            let bytes = Array(string.utf8)
            guard bytes.first == UInt8(ascii: "[") else {
                return string.validatedAndNormalizedURLComponent(.registeredName, emptiness: .allowed)
            }
            guard bytes.last == UInt8(ascii: "]") else { return nil }
            let address = bytes[1..<(bytes.count - 1)]
            guard Self.isIPv6Address(address) || Self.isIPvFuture(address) else { return nil }
            return string
        }

        /// ```
        /// IPvFuture = "v" 1*HEXDIG "." 1*( unreserved / sub-delims / ":" )
        /// ```
        private static func isIPvFuture(_ bytes: ArraySlice<UInt8>) -> Bool {
            guard let first = bytes.first, first == UInt8(ascii: "v") || first == UInt8(ascii: "V") else {
                return false
            }
            let rest = bytes.dropFirst()
            guard let dot = rest.firstIndex(of: UInt8(ascii: ".")) else { return false }
            let version = rest[..<dot]
            let address = rest[(dot + 1)...]
            return !version.isEmpty && version.allSatisfy(\.isHexCharacter)
                && !address.isEmpty
                && address.allSatisfy { $0.isUnreserved || $0.isSubDelims || $0 == UInt8(ascii: ":") }
        }

        /// The eight 16-bit pieces, at most one run of them elided as `::`, the last two optionally
        /// written as an IPv4 address. For example `2001:db8::1`, `::`, `::ffff:192.0.2.1`.
        /// ```
        /// IPv6address =                            6( h16 ":" ) ls32
        ///             /                       "::" 5( h16 ":" ) ls32
        ///             / …
        ///             / [ *6( h16 ":" ) h16 ] "::"
        /// ls32        = ( h16 ":" h16 ) / IPv4address
        /// h16         = 1*4HEXDIG
        /// ```
        private static func isIPv6Address(_ bytes: ArraySlice<UInt8>) -> Bool {
            let pieceCount = 8
            let colon = UInt8(ascii: ":")

            // Split at the `::`, if any: `2001:db8::1` → `2001:db8` and `1`.
            var head = bytes
            var tail: ArraySlice<UInt8>?
            if let elision = bytes.indices.dropLast().first(where: { bytes[$0] == colon && bytes[$0 + 1] == colon }) {
                head = bytes[..<elision]
                tail = bytes[(elision + 2)...]
            }
            func groups(_ part: ArraySlice<UInt8>) -> [ArraySlice<UInt8>] {
                part.isEmpty ? [] : part.split(separator: colon, omittingEmptySubsequences: false)
            }
            let headGroups = groups(head)
            let tailGroups = tail.map(groups) ?? []
            let allGroups = headGroups + tailGroups

            // Only the very last group may be an IPv4 address, and it counts for two pieces.
            var count = allGroups.count
            for (index, group) in allGroups.enumerated() {
                let isLast = index == allGroups.count - 1 && (tail == nil || !tailGroups.isEmpty)
                if isLast, group.contains(UInt8(ascii: ".")) {
                    guard Self.isIPv4Address(group) else { return false }
                    count += 1
                    continue
                }
                guard (1...4).contains(group.count), group.allSatisfy(\.isHexCharacter) else { return false }
            }
            guard tail != nil else { return count == pieceCount }
            return count < pieceCount
        }

        /// ```
        /// IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet
        /// dec-octet   = DIGIT / %x31-39 DIGIT / "1" 2DIGIT / "2" %x30-34 DIGIT / "25" %x30-35
        /// ```
        private static func isIPv4Address(_ bytes: ArraySlice<UInt8>) -> Bool {
            let octets = bytes.split(separator: UInt8(ascii: "."), omittingEmptySubsequences: false)
            return octets.count == 4 && octets.allSatisfy(Self.isDecimalOctet)
        }

        /// `0`–`255` without leading zeros.
        private static func isDecimalOctet(_ bytes: ArraySlice<UInt8>) -> Bool {
            guard (1...3).contains(bytes.count), bytes.allSatisfy(Self.isDigit) else { return false }
            guard bytes.count == 1 || bytes.first != UInt8(ascii: "0") else { return false }
            let value = bytes.reduce(0) { $0 * 10 + Int($1 - UInt8(ascii: "0")) }
            return value <= UInt8.max
        }

        private static func isDigit(_ byte: UInt8) -> Bool {
            (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
        }
    }
}

extension String {
    /// Creates a `String` from an ``IMAPServer/Host``.
    ///
    /// - parameter other: The host to convert.
    public init(_ other: IMAPServer.Host) {
        self = other.stringValue
    }
}

extension IMAPServer.Host: ExpressibleByStringLiteral {
    /// Creates a host from a string literal.
    ///
    /// A literal is written by the programmer, so an invalid one is a bug to be caught on first
    /// run rather than handled. Use ``init(_:)`` for anything else.
    ///
    /// - parameter value: The string literal.
    /// - Precondition: `value` is a valid `host`; this traps if it isn't.
    public init(stringLiteral value: String) {
        guard let normalized = Self.normalized(value) else {
            preconditionFailure("Invalid host: \(String(reflecting: value))")
        }
        self.init(unchecked: normalized)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMAPServer(_ server: IMAPServer) -> Int {
        self.writeIfExists(server.userAuthenticationMechanism) { authMechanism in
            self.writeUserAuthenticationMechanism(authMechanism) + self.writeString("@")
        } + self.writeString(server.host.stringValue)
            + self.writeIfExists(server.port) { port in
                self.writeString(":\(port)")
            }
    }
}
