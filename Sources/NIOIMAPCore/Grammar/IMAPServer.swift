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
/// It includes the hostname and optional port, plus optional user and authentication mechanism information.
/// IMAP URLs use this in the format `imap://[userauth@]hostname[:port]/...` (RFC 2192, extended by RFC 4467).
///
/// ### Components
///
/// - **Hostname**: The server's fully-qualified domain name (required)
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
/// imap://example.com/INBOX/;uid=20;auth=PLAIN
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

    /// The hostname or fully-qualified domain name of the IMAP server.
    public var host: String

    /// Optional TCP port number for the IMAP service.
    ///
    /// If not specified, the default IMAP port (143) or secure IMAP port (993) should be used
    /// based on the connection security settings.
    public var port: Int?

    /// Creates a new IMAP server connection specification.
    /// - parameter userAuthenticationMechanism: Optional user and/or authentication mechanism. Defaults to `nil`.
    /// - parameter host: The hostname of the server.
    /// - parameter port: Optional TCP port number. Defaults to `nil`.
    public init(userAuthenticationMechanism: UserAuthenticationMechanism? = nil, host: String, port: Int? = nil) {
        self.userAuthenticationMechanism = userAuthenticationMechanism
        self.host = host
        self.port = port
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMAPServer(_ server: IMAPServer) -> Int {
        self.writeIfExists(server.userAuthenticationMechanism) { authMechanism in
            self.writeUserAuthenticationMechanism(authMechanism) + self.writeString("@")
        } + self.writeString("\(server.host)")
            + self.writeIfExists(server.port) { port in
                self.writeString(":\(port)")
            }
    }
}
