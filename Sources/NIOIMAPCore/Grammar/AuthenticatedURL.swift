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

/// Complete URLAUTH authorization information for an IMAP URL.
///
/// A ``AuthenticatedURL`` combines all authorization components needed to verify a URLAUTH-authorized
/// IMAP URL. It pairs the authorization parameters (expiration and access) with the verification
/// information (mechanism and token).
///
/// The `;URLAUTH=<access>:<mechanism>:<token>` component is appended to IMAP URLs
/// according to RFC 4467. It is used when:
///
/// 1. **Generating URLAUTH URLs** (GENURLAUTH command): Server creates authorization information
/// 2. **Verifying URLAUTH URLs** (URLFETCH command): Server validates the authorization
/// 3. **Storing URLAUTH URLs**: Applications preserve complete authorization information
///
/// ### URLAUTH Component Structure
///
/// A complete URLAUTH component consists of:
/// - `;URLAUTH=<access>` - From ``AuthenticatedURLRump/access``
/// - `:<mechanism>` - From ``AuthenticatedURLVerifier/urlAuthenticationMechanism``
/// - `:<token>` - From ``AuthenticatedURLVerifier/encodedAuthenticationURL``
///
/// ### Examples
///
/// Basic anonymous authorization:
/// ```
/// ;URLAUTH=anonymous:internal:91354a473744909de610943775f92038
/// ```
///
/// User-restricted authorization with expiration:
/// ```
/// ;EXPIRE=2025-12-31T23:59:59Z;URLAUTH=user+fred:internal:abc123def456
/// ```
///
/// Submission entity authorization:
/// ```
/// ;URLAUTH=submit+alice:internal:xyz789
/// ```
///
/// In a complete URLAUTH URL returned by GENURLAUTH:
/// ```
/// C: a001 GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038"
/// S: a001 OK GENURLAUTH completed
/// ```
///
/// When used in URLFETCH:
/// ```
/// C: a002 URLFETCH "imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038"
/// S: * URLFETCH ("imap://owner@example.com/INBOX/;uid=20;urlauth=anonymous:internal:91354a473744909de610943775f92038" "message-data")
/// S: a002 OK URLFETCH completed
/// ```
///
/// ## Related types
///
/// - ``AuthenticatedURLRump`` provides expiration and access information
/// - ``AuthenticatedURLVerifier`` provides mechanism and token for verification
/// - ``RumpAuthenticatedURL`` pairs a network message path with this authorization
/// - ``FullAuthenticatedURL`` combines network message path and authorization for complete URLs
/// - ``URLCommand`` uses authentication in fetch operations
/// - ``Response/untagged(_:)`` contains the response, with ``MessageData/generateAuthorizedURL(_:)`` for GENURLAUTH results
///
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
/// - SeeAlso: [RFC 4467 Section 5](https://datatracker.ietf.org/doc/html/rfc4467#section-5) - Generation of URLAUTH-Authorized URLs
/// - SeeAlso: [RFC 4467 Section 6](https://datatracker.ietf.org/doc/html/rfc4467#section-6) - Validation of URLAUTH-authorized URLs
public struct AuthenticatedURL: Hashable, Sendable {
    /// The URLAUTH rump containing expiration and access restrictions.
    ///
    /// Specifies when the URL expires (if specified) and who is authorized to use it.
    public var authenticatedURL: AuthenticatedURLRump

    /// The verification information needed to validate the authorization.
    ///
    /// Contains the mechanism used for token generation and the hexadecimal-encoded token itself.
    public var verifier: AuthenticatedURLVerifier

    /// Creates a new URLAUTH authorization.
    /// - parameter authenticatedURL: The rump with expiration and access information.
    /// - parameter verifier: The verifier with mechanism and token.
    public init(authenticatedURL: AuthenticatedURLRump, verifier: AuthenticatedURLVerifier) {
        self.authenticatedURL = authenticatedURL
        self.verifier = verifier
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIAuthenticatedURL(_ data: AuthenticatedURL) -> Int {
        self.writeAuthenticatedURLRump(data.authenticatedURL) + self.writeAuthenticatedURLVerifier(data.verifier)
    }
}
