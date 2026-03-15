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

/// A complete URLAUTH-authorized IMAP URL with all authorization and verification information.
///
/// A ``FullAuthenticatedURL`` represents a fully-formed URLAUTH-authorized IMAP URL ready for use
/// in commands like URLFETCH (RFC 4467). It combines:
///
/// 1. **Network Message Path**: Server location and message content reference
/// 2. **Authorization Information**: Complete URLAUTH with access, expiration, mechanism, and token
///
/// This is the endpoint of the GENURL AUTH flow: after GENURLAUTH is issued by the client,
/// the server returns one or more ``FullAuthenticatedURL`` structures wrapped in a GENURLAUTH response.
///
/// ### Complete URL Structure
///
/// A full authenticated URL encompasses:
/// ```
/// imap://[user@]host[:port]/mailbox[;uidvalidity=n]/;uid=m[;section=s][;partial=o.l][;EXPIRE=datetime];URLAUTH=access:mechanism:token
/// ```
///
/// Broken down:
/// - `imap://[user@]host[:port]/mailbox[;uidvalidity=n]/;uid=m[;section=s][;partial=o.l]` - From ``NetworkMessagePath``
/// - `[;EXPIRE=datetime]` - Optional expiration from ``AuthenticatedURL``
/// - `;URLAUTH=access:mechanism:token` - Authorization from ``AuthenticatedURL``
///
/// ### Examples
///
/// Complete GENURLAUTH response:
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038"
/// S: a001 OK GENURLAUTH completed
/// ```
///
/// The returned URL is a complete authenticated URL that can be submitted to URLFETCH:
/// ```
/// C: a002 URLFETCH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038"
/// S: * URLFETCH ("imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038" "message-data")
/// S: a002 OK URLFETCH completed
/// ```
///
/// URL with expiration and user restriction:
/// ```
/// imap://user@example.com/INBOX/;uid=20;EXPIRE=2025-12-31T23:59:59Z;URLAUTH=user+fred:internal:abc123def456
/// ```
///
/// ## Workflow
///
/// 1. **Client Issues GENURLAUTH**: Sends a message path and authorization mechanism
/// 2. **Server Generates Authorization**: Creates token using mailbox access key
/// 3. **Server Returns URL**: Wraps the result in a ``FullAuthenticatedURL`` as part of GENURLAUTH response
/// 4. **Client Uses URL**: Submits the complete URL to URLFETCH command
/// 5. **Server Validates and Returns Data**: Verifies token and returns message content
///
/// ## Related Types
///
/// - ``NetworkMessagePath`` provides server and message content specification
/// - ``AuthenticatedURL`` provides complete URLAUTH authorization
/// - ``RumpAuthenticatedURL`` provides URL with rump information
/// - ``Response/untagged(_:)`` and ``MessageData/generateAuthorizedURL(_:)`` wrap GENURLAUTH responses
/// - ``URLCommand/fetch(path:authenticatedURL:)`` uses authenticated URLs in URLFETCH
///
/// - SeeAlso: [RFC 4467 Section 5](https://datatracker.ietf.org/doc/html/rfc4467#section-5) - Generation of URLAUTH-Authorized URLs
/// - SeeAlso: [RFC 4467 Section 7](https://datatracker.ietf.org/doc/html/rfc4467#section-7) - GENURLAUTH and URLFETCH Commands
public struct FullAuthenticatedURL: Hashable, Sendable {
    /// The network-accessible IMAP URL pointing to the message.
    ///
    /// Includes server location (hostname, port, optional user), mailbox reference,
    /// message UID, and optionally message section and byte range.
    public var networkMessagePath: NetworkMessagePath

    /// The complete URLAUTH authorization information.
    ///
    /// Includes expiration date (if specified), access identifier, authorization mechanism,
    /// and verification token.
    public var authenticatedURL: AuthenticatedURL

    /// Creates a new full authenticated URL.
    /// - parameter networkMessagePath: The network-accessible message URL.
    /// - parameter authenticatedURL: The complete URLAUTH authorization.
    public init(networkMessagePath: NetworkMessagePath, authenticatedURL: AuthenticatedURL) {
        self.networkMessagePath = networkMessagePath
        self.authenticatedURL = authenticatedURL
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthIMAPURLFull(_ data: FullAuthenticatedURL) -> Int {
        self.writeAuthenticatedURL(data.networkMessagePath) + self.writeIAuthenticatedURL(data.authenticatedURL)
    }
}
