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

/// An access restriction identifier that controls who may use a URLAUTH-authorized URL.
///
/// The access identifier is part of the `URLAUTH` component appended to IMAP URLs (RFC 4467).
/// It restricts which users or sessions are permitted to access the message data referenced by the URL.
/// Each ``AuthenticatedURLRump`` includes an access identifier that determines authorization policy.
///
/// ### Access types
///
/// - ``anonymous``: Any user, including non-authenticated sessions, may access the URL
/// - ``authenticateUser``: Only authenticated (non-anonymous) sessions may access the URL
/// - ``user(_:)``: Only a specific authenticated user may access the URL
/// - ``submit(_:)``: Only a message submission entity on behalf of a specific user may access the URL
///
/// ### Examples
///
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:..."
/// ```
///
/// The `anonymous` access identifier allows any session to fetch the URL. The line
/// `S: * GENURLAUTH ...` is the ``Response/untagged(_:)`` containing a ``MessageData/generateAuthorizedURL(_:)``
/// response with the generated URLAUTH URL.
///
/// In contrast, `user+` restricts to a specific user:
/// ```
/// C: a002 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=user+fred" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=user+fred:internal:..."
/// ```
///
/// Only sessions authenticated as "fred" may use this URL.
///
/// ## Related types
///
/// See ``AuthenticatedURLRump`` for how access identifiers are combined with expiration dates,
/// ``AuthenticatedURLVerifier`` for the verification token, and ``AuthenticatedURL`` for
/// the complete authorization structure.
///
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
/// - SeeAlso: [RFC 4467 Section 2.3](https://datatracker.ietf.org/doc/html/rfc4467#section-2.3) - Authorized Access Identifier
public enum Access: Hashable, Sendable {
    /// Permits use of the URL by a message submission entity acting on behalf of a specific user.
    ///
    /// When using this access identifier, only IMAP sessions with authorization as a message submission
    /// entity are permitted to access the URL. The submitted user identifier in the ``EncodedUser`` is not
    /// validated by the IMAP server, but must be verified by the message submission entity before
    /// contacting the server.
    ///
    /// Encoded in IMAP URLs as `submit+<encoded-user>`.
    case submit(EncodedUser)

    /// Permits use of the URL by a specific authenticated user.
    ///
    /// Only IMAP sessions that are authenticated (logged in) as the specified user are permitted
    /// to access the URL. If using SASL mechanisms that provide both authorization and authentication
    /// identifiers, the authorization identifier must match this user identifier.
    ///
    /// Encoded in IMAP URLs as `user+<encoded-user>`.
    case user(EncodedUser)

    /// Permits use of the URL by any authenticated (non-anonymous) user.
    ///
    /// Any IMAP session that is authenticated and not anonymous may access the URL. This does not
    /// restrict access to a specific user, only that the session must be authenticated.
    ///
    /// Encoded in IMAP URLs as `authuser`.
    case authenticateUser

    /// Permits unrestricted use of the URL, including by non-authenticated sessions.
    ///
    /// Any IMAP session, including anonymous sessions and non-authenticated connections, may access
    /// the URL. This provides the least restriction and should be used with caution for public data.
    ///
    /// Encoded in IMAP URLs as `anonymous`.
    case anonymous
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAccess(_ data: Access) -> Int {
        switch data {
        case .submit(let user):
            return self.writeString("submit+") + self.writeEncodedUser(user)
        case .user(let user):
            return self.writeString("user+") + self.writeEncodedUser(user)
        case .authenticateUser:
            return self.writeString("authuser")
        case .anonymous:
            return self.writeString("anonymous")
        }
    }
}
