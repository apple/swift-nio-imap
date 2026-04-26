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

/// A network-accessible IMAP URL pointing to a specific message or message part on a remote server.
///
/// A network message path combines an IMAP server specification (``IMAPServer``) with a message path
/// (``MessagePath``) to create a complete IMAP URL that can be used to fetch message content from
/// a remote IMAP server. This is the full URL that appears in IMAP URL schemes (RFC 2192/5092)
/// and URLAUTH-authorized URLs (RFC 4467).
///
/// The network message path is encoded as `imap://[user[@;auth]]@host[:port]/mailbox/;uidvalidity=N/;uid=M[;section=S][;partial=start.length]`.
///
/// ### Usage in IMAP URLs
///
/// Represents the base URL before any URLAUTH authorization is added:
/// ```
/// imap://user@example.com/INBOX/;uidvalidity=100/;uid=20
/// ```
///
/// ### Usage in URLAUTH
///
/// In RFC 4467 URLAUTH authorization, this type forms the "rump URL" which is used to generate
/// and verify authorization tokens. The complete URLAUTH URL has the form:
/// ```
/// imap://user@example.com/INBOX/;uidvalidity=100/;uid=20;urlauth=anonymous:internal:TOKEN
/// ```
///
/// The ``NetworkMessagePath`` represents everything before `;urlauth=`, and the remaining portion
/// is provided by ``AuthenticatedURLRump`` and ``AuthenticatedURLVerifier``.
///
/// ### Examples
///
/// In a GENURLAUTH command:
/// ```
/// C: a001 GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous:internal:..."
/// S: a001 OK GENURLAUTH completed
/// ```
///
/// The `imap://owner@example.com/INBOX/;uid=20` portion would be a ``NetworkMessagePath``.
///
/// ## Related types
///
/// - ``MessagePath`` provides the message location (mailbox, UID, section, range)
/// - ``IMAPServer`` provides the server connection details
/// - ``RumpAuthenticatedURL`` combines this with authorization information for URLAUTH
/// - ``FullAuthenticatedURL`` extends this with authorization verification
/// - ``URLCommand`` uses network message paths in fetch operations
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
/// - SeeAlso: [RFC 4467 Section 6](https://datatracker.ietf.org/doc/html/rfc4467#section-6) - Validation of URLAUTH-authorized URLs
public struct NetworkMessagePath: Hashable, Sendable {
    /// The IMAP server containing the message.
    public var server: IMAPServer

    /// The message location within the server (mailbox, UID, optional section and byte range).
    public var messagePath: MessagePath

    /// Creates a new network-accessible IMAP message URL.
    /// - parameter server: The server containing the message.
    /// - parameter messagePath: The message location within the server.
    public init(server: IMAPServer, messagePath: MessagePath) {
        self.server = server
        self.messagePath = messagePath
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticatedURL(_ data: NetworkMessagePath) -> Int {
        self.writeString("imap://") + self.writeIMAPServer(data.server) + self.writeString("/")
            + self.writeMessagePath(data.messagePath)
    }
}
