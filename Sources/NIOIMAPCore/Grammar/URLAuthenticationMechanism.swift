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

/// The algorithm name for URLAUTH verification token generation and validation.
///
/// In RFC 4467 URLAUTH-authorized URLs, the authorization token is generated using an
/// algorithm specified by a mechanism name. The mechanism determines how the authorization
/// token is calculated from the URL and mailbox access key.
///
/// The mechanism name appears in the URLAUTH component as:
/// `;URLAUTH=<access>:<mechanism>:<token>`
///
/// The mechanism name is case-insensitive and can be any server-supported mechanism.
/// The most common mechanism is `INTERNAL`, which indicates the server uses its own
/// token generation algorithm (typically HMAC-based).
///
/// ### Examples
///
/// INTERNAL mechanism (server's default algorithm):
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:..."
/// ```
///
/// Custom mechanism (if server supports it):
/// ```
/// C: a002 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous" XSAMPLE
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:xsample:..."
/// ```
///
/// In an ``AuthenticatedURLVerifier`` pairing mechanism with token:
/// ```
/// AuthenticatedURLVerifier(
///   urlAuthenticationMechanism: URLAuthenticationMechanism("INTERNAL"),
///   encodedAuthenticationURL: EncodedAuthenticatedURL(data: "91354a473744909de610943775f92038")
/// )
/// // Represents: :internal:91354a473744909de610943775f92038
/// ```
///
/// ## Related Types
///
/// - ``AuthenticatedURLVerifier`` pairs the mechanism with a verification token
/// - ``AuthenticatedURL`` combines the URL rump with verification details
/// - ``RumpURLAndMechanism`` provides mechanism information for GENURLAUTH
/// - ``EncodedAuthenticatedURL`` wraps the hexadecimal verification token
///
/// - SeeAlso: [RFC 4467 Section 2.4](https://datatracker.ietf.org/doc/html/rfc4467#section-2.4) - Authorization Mechanism
/// - SeeAlso: [RFC 4467 Section 2.4.1](https://datatracker.ietf.org/doc/html/rfc4467#section-2.4.1) - INTERNAL Authorization Mechanism
public struct URLAuthenticationMechanism: Hashable, Sendable {
    /// The `INTERNAL` mechanism, indicating the server uses its default token generation algorithm.
    ///
    /// The INTERNAL mechanism does not disclose the mailbox access key to the client and uses
    /// a server-chosen algorithm (typically HMAC-based) for token generation. This is the
    /// recommended and most commonly used mechanism.
    ///
    /// - SeeAlso: [RFC 4467 Section 2.4.1](https://datatracker.ietf.org/doc/html/rfc4467#section-2.4.1)
    public static let `internal` = Self("INTERNAL")

    /// The mechanism name as a string.
    ///
    /// This is the name that appears in the URLAUTH component (case may be normalized by the server).
    /// Common values include `"INTERNAL"` for the standard mechanism, but servers may support
    /// other mechanisms.
    internal let stringValue: String

    /// Creates a new mechanism by name.
    /// - parameter stringValue: The mechanism name (e.g., "INTERNAL").
    public init(_ stringValue: String) {
        self.stringValue = stringValue
    }
}

extension String {
    public init(_ other: URLAuthenticationMechanism) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLAuthenticationMechanism(_ data: URLAuthenticationMechanism) -> Int {
        self.writeString(data.stringValue)
    }
}
