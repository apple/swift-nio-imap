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

/// The authorization components of a URLAUTH URL (expiration and access restrictions).
///
/// In RFC 4467 URLAUTH-authorized URLs, the authorization information is appended to the URL
/// as `;EXPIRE=<date>;URLAUTH=<access>:<mechanism>:<token>`. The ``AuthenticatedURLRump``
/// wraps the optional expiration date and access identifier portions (everything before the
/// `:<mechanism>:<token>`), while ``AuthenticatedURLVerifier`` wraps the verification components.
///
/// Together, ``AuthenticatedURLRump`` and ``AuthenticatedURLVerifier`` form a complete
/// ``AuthenticatedURL`` that defines all authorization parameters for a URLAUTH-authorized URL.
///
/// ### URLAUTH format
///
/// A complete URLAUTH component has the form:
/// ```
/// ;EXPIRE=<datetime>;URLAUTH=<access>:<mechanism>:<token>
/// ```
///
/// Broken down:
/// - `;EXPIRE=<datetime>` (optional): Expiration date via ``expire``
/// - `;URLAUTH=` (literal): Fixed prefix
/// - `<access>` (required): Access identifier via ``access`` (`anonymous`, `authuser`, `user+userid`, or `submit+userid`)
/// - `:` (literal): Separator
/// - `<mechanism>:<token>` (required): Provided by ``AuthenticatedURLVerifier``
///
/// ### Examples
///
/// Expiration with access restriction:
/// ```
/// ;EXPIRE=2025-12-31T23:59:59Z;URLAUTH=user+fred
/// ```
///
/// No expiration, anonymous access:
/// ```
/// ;URLAUTH=anonymous
/// ```
///
/// Submission entity restriction:
/// ```
/// ;URLAUTH=submit+alice
/// ```
///
/// In a complete URLAUTH URL:
/// ```
/// imap://owner@example.com/INBOX/;uid=20;EXPIRE=2025-12-31T23:59:59Z;URLAUTH=anonymous:internal:TOKEN
/// ```
///
/// ## Related types
///
/// - ``Expire`` wraps the optional expiration date
/// - ``Access`` defines the access identifier
/// - ``AuthenticatedURLVerifier`` provides mechanism and token
/// - ``AuthenticatedURL`` combines rump and verifier
/// - ``RumpAuthenticatedURL`` pairs network message path with rump
///
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
/// - SeeAlso: [RFC 4467 Section 2.3](https://datatracker.ietf.org/doc/html/rfc4467#section-2.3) - Authorized Access Identifier
public struct AuthenticatedURLRump: Hashable, Sendable {
    /// Optional expiration date and time for the URL.
    ///
    /// When specified, the IMAP server must reject the URL after this date and time.
    /// When `nil`, the URL has no expiration (but may still be revoked by other means).
    public var expire: Expire?

    /// Access restrictions that control who may use the URL.
    ///
    /// Determines whether the URL can be used by anonymous users, any authenticated user,
    /// a specific authenticated user, or a message submission entity on behalf of a user.
    public var access: Access

    /// Creates a new URLAUTH rump with expiration and access information.
    /// - parameter expire: Optional expiration date. Defaults to `nil`.
    /// - parameter access: Access identifier (required).
    public init(expire: Expire? = nil, access: Access) {
        self.expire = expire
        self.access = access
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAuthenticatedURLRump(_ data: AuthenticatedURLRump) -> Int {
        self.writeIfExists(data.expire) { expire in
            self.writeExpire(expire)
        } + self.writeString(";URLAUTH=") + self.writeAccess(data.access)
    }
}
