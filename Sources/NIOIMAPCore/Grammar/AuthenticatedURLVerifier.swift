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

/// The verification components of a URLAUTH authorization (mechanism and token).
///
/// In RFC 4467 URLAUTH-authorized URLs, the verification information is appended to the URL
/// as `:<mechanism>:<token>` (after the access identifier in the URLAUTH component).
/// The ``AuthenticatedURLVerifier`` wraps the mechanism name and the hexadecimal-encoded
/// verification token.
///
/// The verifier allows the IMAP server to validate that the URL has been properly authorized
/// by verifying the token using the specified mechanism and a stored mailbox access key.
///
/// ### Verification process (RFC 4467 Section 6)
///
/// When a URLFETCH command is issued with a URLAUTH-authorized URL:
///
/// 1. Server extracts the mechanism and token from the URL
/// 2. Server recalculates the token using the specified mechanism and the mailbox access key
/// 3. Server compares the calculated token with the supplied token
/// 4. If they match, the URL is valid and message data is returned
/// 5. If they don't match, authorization fails and the URL is invalid
///
/// ### Examples
///
/// Complete URLAUTH with verifier:
/// ```
/// ;URLAUTH=anonymous:internal:91354a473744909de610943775f92038
/// ```
///
/// Where:
/// - `;URLAUTH=anonymous` is from ``AuthenticatedURLRump``
/// - `:internal:91354a473744909de610943775f92038` is from ``AuthenticatedURLVerifier``
///
/// In a URLFETCH response showing the verifier:
/// ```
/// C: a001 URLFETCH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038"
/// S: * URLFETCH ("imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038" "message-data")
/// ```
///
/// ## Related types
///
/// - ``URLAuthenticationMechanism`` specifies the token generation algorithm
/// - ``EncodedAuthenticatedURL`` wraps the hexadecimal-encoded token
/// - ``AuthenticatedURLRump`` provides the access and expiration information
/// - ``AuthenticatedURL`` combines rump and verifier for complete authorization
/// - ``RumpAuthenticatedURL`` pairs network message path with authorization
///
/// - SeeAlso: [RFC 4467 Section 2.4](https://datatracker.ietf.org/doc/html/rfc4467#section-2.4) - Authorization Mechanism
/// - SeeAlso: [RFC 4467 Section 6](https://datatracker.ietf.org/doc/html/rfc4467#section-6) - Validation of URLAUTH-authorized URLs
public struct AuthenticatedURLVerifier: Hashable, Sendable {
    /// The mechanism used to generate and verify the authorization token.
    ///
    /// Specifies the algorithm used by the server to generate the token during GENURLAUTH
    /// and to verify it during URLFETCH. Common values include `INTERNAL` for the server's
    /// default algorithm.
    public var urlAuthenticationMechanism: URLAuthenticationMechanism

    /// The hexadecimal-encoded authorization token.
    ///
    /// An ASCII-encoded hexadecimal string (at least 32 hex digits, representing 128+ bits)
    /// that serves as proof of authorization. The server recalculates this token during
    /// URLFETCH to verify that the URL has been properly authorized.
    public var encodedAuthenticationURL: EncodedAuthenticatedURL

    /// Creates a new URLAUTH verifier with mechanism and token.
    /// - parameter urlAuthMechanism: The mechanism used for token verification.
    /// - parameter encodedAuthenticationURL: The hexadecimal-encoded verification token.
    public init(urlAuthMechanism: URLAuthenticationMechanism, encodedAuthenticationURL: EncodedAuthenticatedURL) {
        self.urlAuthenticationMechanism = urlAuthMechanism
        self.encodedAuthenticationURL = encodedAuthenticationURL
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticatedURLVerifier(_ data: AuthenticatedURLVerifier) -> Int {
        self.writeString(":") + self.writeURLAuthenticationMechanism(data.urlAuthenticationMechanism)
            + self.writeString(":") + self.writeEncodedAuthenticationURL(data.encodedAuthenticationURL)
    }
}
