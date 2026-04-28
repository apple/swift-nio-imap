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

/// A percent-encoded SASL authentication mechanism name for use in IMAP URLs.
///
/// IMAP URLs may specify an authentication mechanism requirement using the `;AUTH=` parameter.
/// When the mechanism name contains characters that are not allowed in URLs, the name must be
/// percent-encoded using UTF-8 followed by hexadecimal encoding (RFC 2192, RFC 3986).
///
/// Wraps a percent-encoded authentication mechanism name for use in URL construction.
/// The encoded string contains only ASCII-safe characters and can be safely included in IMAP URL syntax.
///
/// ### Examples
///
/// A standard mechanism like "PLAIN" would typically not require encoding:
/// ```
/// imap://user@example.com/INBOX/;uid=20;auth=PLAIN
/// ```
///
/// A custom mechanism with special characters might be percent-encoded:
/// ```
/// imap://user@example.com/INBOX/;uid=20;auth=MY-CUSTOM%2DAUTH
/// ```
///
/// In an IMAP URL structure:
/// ```
/// IMAPServer(
///   userAuthenticationMechanism: UserAuthenticationMechanism(
///     encodedUser: EncodedUser(data: "user"),
///     authenticationMechanism: IMAPURLAuthenticationMechanism.type(
///       EncodedAuthenticationType(authenticationType: "PLAIN")
///     )
///   ),
///   host: "example.com"
/// )
/// ```
///
/// ## Related types
///
/// See ``IMAPURLAuthenticationMechanism`` for the authentication mechanism specification,
/// ``UserAuthenticationMechanism`` for how mechanisms are combined with user identifiers,
/// and ``IMAPServer`` for the complete server specification.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
public struct EncodedAuthenticationType: Hashable, Sendable {
    /// The percent-encoded SASL mechanism name.
    ///
    /// Contains only URL-safe ASCII characters. Mechanism names with non-ASCII or special
    /// characters are percent-encoded according to RFC 3986 using UTF-8.
    public var authenticationType: String

    /// Creates a new percent-encoded authentication mechanism name.
    /// - parameter authenticationType: The percent-encoded mechanism name string.
    public init(authenticationType: String) {
        self.authenticationType = authenticationType
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedAuthenticationType(_ type: EncodedAuthenticationType) -> Int {
        self.writeString(type.authenticationType)
    }
}
