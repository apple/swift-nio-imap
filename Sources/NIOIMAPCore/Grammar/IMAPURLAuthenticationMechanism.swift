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

/// An authentication mechanism requirement or constraint for an IMAP URL connection.
///
/// IMAP URLs can specify which SASL authentication mechanism must be used (or allowed) when
/// connecting to the server. This provides a way to enforce security policies or specific
/// authentication methods in URL-based operations.
///
/// The mechanism specification appears in the server component of an IMAP URL as `;AUTH=` parameter
/// (RFC 2192/5092). It is part of the ``UserAuthenticationMechanism`` that appears in ``IMAPServer`` definitions.
///
/// ### Examples
///
/// Allow any appropriate authentication mechanism:
/// ```
/// imap://user@example.com/;auth=*
/// ```
///
/// Require PLAIN mechanism:
/// ```
/// imap://user@example.com/;auth=PLAIN
/// ```
///
/// Require CRAM-MD5 mechanism:
/// ```
/// imap://user@example.com/;auth=CRAM-MD5
/// ```
///
/// In a server specification with specific user and mechanism:
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
/// // Represents: imap://user@example.com/;auth=PLAIN
/// ```
///
/// ## Related Types
///
/// - ``UserAuthenticationMechanism`` combines user and mechanism specifications
/// - ``IMAPServer`` uses mechanism specifications in server definitions
/// - ``EncodedAuthenticationType`` wraps percent-encoded mechanism names
/// - ``URLAuthenticationMechanism`` is used for URLAUTH token generation mechanisms
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4422](https://datatracker.ietf.org/doc/html/rfc4422) - SASL Authentication and Authorization
public enum IMAPURLAuthenticationMechanism: Hashable, Sendable {
    /// Allow any appropriate SASL authentication mechanism.
    ///
    /// The client may choose any mechanism that is suitable. This is the most flexible option
    /// and allows the server to negotiate the best mechanism available.
    ///
    /// Encoded in IMAP URLs as `;AUTH=*`.
    case any

    /// Require a specific SASL authentication mechanism.
    ///
    /// Only the specified mechanism may be used. This enforces a particular authentication
    /// method, useful for security policies or compatibility requirements.
    ///
    /// Encoded in IMAP URLs as `;AUTH=<mechanism>`.
    case type(EncodedAuthenticationType)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMAPURLAuthenticationMechanism(_ data: IMAPURLAuthenticationMechanism) -> Int
    {
        switch data {
        case .any:
            return self.writeString(";AUTH=*")
        case .type(let type):
            return self.writeString(";AUTH=") + self.writeEncodedAuthenticationType(type)
        }
    }
}
