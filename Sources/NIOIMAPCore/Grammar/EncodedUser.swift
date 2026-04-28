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

/// A percent-encoded user identifier for use in IMAP URLs and URLAUTH components.
///
/// User identifiers in IMAP URLs are percent-encoded to ensure they contain only URL-safe
/// characters. This encoding is applied when a user identifier contains non-ASCII characters,
/// spaces, or special characters that are not allowed in URL syntax (RFC 2192, RFC 3986).
///
/// Wraps a percent-encoded user identifier for use in server specifications
/// (via ``UserAuthenticationMechanism`` and ``IMAPServer``) and in URLAUTH access identifiers
/// (via ``Access`` with `user+` and `submit+` prefixes).
///
/// ### Examples
///
/// A user named "Frédéric" would be percent-encoded as "Fr%C3%A9d%C3%A9ric" (UTF-8 followed by hex encoding).
///
/// In a server specification:
/// ```
/// imap://Fr%C3%A9d%C3%A9ric@example.com/INBOX/;uid=20
/// ```
///
/// In a URLAUTH access identifier restricting to a specific user:
/// ```
/// imap://owner@example.com/INBOX/;uid=20;urlauth=user+Fr%C3%A9d%C3%A9ric:internal:...
/// ```
///
/// In a URLAUTH submission entity identifier:
/// ```
/// imap://owner@example.com/INBOX/;uid=20;urlauth=submit+Fr%C3%A9d%C3%A9ric:internal:...
/// ```
///
/// ## Related types
///
/// See ``Access`` for how encoded users are used in URLAUTH access identifiers,
/// ``UserAuthenticationMechanism`` for server-level user specifications, and
/// ``IMAPServer`` for the complete server connection information.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
public struct EncodedUser: Hashable, Sendable {
    /// The percent-encoded user identifier string.
    ///
    /// Contains only URL-safe ASCII characters. User identifiers with non-ASCII or special
    /// characters are percent-encoded according to RFC 3986 using UTF-8.
    public var data: String

    /// Creates a new percent-encoded user identifier.
    /// - parameter data: The percent-encoded user identifier string.
    public init(data: String) {
        self.data = data
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedUser(_ user: EncodedUser) -> Int {
        self.writeString(user.data)
    }
}
