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

/// A network-accessible message URL with URLAUTH authorization information.
///
/// A ``RumpAuthenticatedURL`` combines a complete message URL on a network-accessible server
/// (``NetworkMessagePath``) with URLAUTH authorization information (``AuthenticatedURLRump``).
/// Represents a URL that can be resolved to fetch message content with proper authorization.
///
/// The "rump" term refers to the URL portion used for token generation and verification in
/// RFC 4467. In URLAUTH processing:
///
/// 1. **Token Generation**: The server uses the network message path plus the access identifier
///    to generate an authorization token
/// 2. **Rump URL Formation**: The "rump URL" is everything up to (but not including) the
///    `:mechanism:token` portion
/// 3. **Complete URL**: The rump is combined with ``AuthenticatedURLVerifier`` to form a
///    complete URLAUTH-authorized URL
///
/// ### URL Structure
///
/// A rump authenticated URL before verification is appended:
/// ```
/// imap://user@example.com/INBOX/;uidvalidity=100/;uid=20;EXPIRE=2025-12-31T23:59:59Z;URLAUTH=anonymous
/// ```
///
/// After the server appends verification information:
/// ```
/// imap://user@example.com/INBOX/;uidvalidity=100/;uid=20;EXPIRE=2025-12-31T23:59:59Z;URLAUTH=anonymous:internal:TOKEN
/// ```
///
/// ### RFC 4467 Usage
///
/// In GENURLAUTH command processing:
/// ```
/// C: a001 GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a..."
/// S: a001 OK GENURLAUTH completed
/// ```
///
/// The server converts the client's "rump URL" (without mechanism and token) into a complete URL
/// by appending `:internal:<calculated-token>`.
///
/// ## Related types
///
/// - ``NetworkMessagePath`` provides the server and message location
/// - ``AuthenticatedURLRump`` provides expiration and access information
/// - ``AuthenticatedURLVerifier`` provides the mechanism and token
/// - ``FullAuthenticatedURL`` combines network path with complete authorization
/// - ``RumpURLAndMechanism`` pairs rump and mechanism for GENURLAUTH
///
/// - SeeAlso: [RFC 4467 Section 5](https://datatracker.ietf.org/doc/html/rfc4467#section-5) - Generation of URLAUTH-Authorized URLs
/// - SeeAlso: [RFC 4467 Section 6](https://datatracker.ietf.org/doc/html/rfc4467#section-6) - Validation of URLAUTH-authorized URLs
public struct RumpAuthenticatedURL: Hashable, Sendable {
    /// The network-accessible message URL (server + message location).
    ///
    /// Specifies which server and which message (with optional section and byte range) this
    /// authorization applies to.
    public var authenticatedURL: NetworkMessagePath

    /// The URLAUTH rump with expiration and access information.
    ///
    /// Contains the expiration date (if any) and access restrictions that control who may use this URL.
    public var authenticatedURLRump: AuthenticatedURLRump

    /// Creates a new rump authenticated URL.
    /// - parameter authenticatedURL: The network message URL.
    /// - parameter authenticatedURLRump: The URLAUTH rump with expiration and access.
    public init(authenticatedURL: NetworkMessagePath, authenticatedURLRump: AuthenticatedURLRump) {
        self.authenticatedURL = authenticatedURL
        self.authenticatedURLRump = authenticatedURLRump
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLRump(_ data: RumpAuthenticatedURL) -> Int {
        self.writeAuthenticatedURL(data.authenticatedURL) + self.writeAuthenticatedURLRump(data.authenticatedURLRump)
    }
}
