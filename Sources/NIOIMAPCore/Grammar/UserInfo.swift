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

/// Optional user identification and/or authentication mechanism requirement for an IMAP server connection.
///
/// Specifies which user context and/or which authentication mechanism should be used
/// when connecting to an IMAP server. It appears in the server component of IMAP URLs
/// (before the `@` symbol). At least one of ``encodedUser`` or ``authenticationMechanism`` must be present.
///
/// For IMAP URLs in RFC 2192 (basic URL scheme), the user provides context for mailbox name resolution.
/// For URLAUTH URLs in RFC 4467, the user typically identifies the owner of the mailbox access key table.
///
/// ### Examples
///
/// User only (mailbox context):
/// ```
/// imap://fred@example.com/INBOX/;uid=20
/// ```
///
/// User with required authentication mechanism:
/// ```
/// imap://fred@example.com/INBOX/;uid=20;auth=PLAIN
/// ```
///
/// Authentication mechanism only (any mechanism allowed):
/// ```
/// imap://example.com/INBOX/;uid=20;auth=*
/// ```
///
/// In a GENURLAUTH command generating a URL for submission entity access:
/// ```
/// C: a001 GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=submit+fred" INTERNAL
/// S: * GENURLAUTH "imap://owner@example.com/INBOX/;uid=20;urlauth=submit+fred:internal:..."
/// ```
///
/// The `owner@example.com` specifies who owns the mailbox access key that will authorize the URL.
///
/// ## Related types
///
/// See ``IMAPServer`` for the complete server specification, ``IMAPURLAuthenticationMechanism`` for
/// authentication mechanism details, and ``EncodedUser`` for the percent-encoded user representation.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4467 Section 5](https://datatracker.ietf.org/doc/html/rfc4467#section-5) - Generation of URLAUTH-Authorized URLs
public struct UserAuthenticationMechanism: Hashable, Sendable {
    /// Optional percent-encoded user identifier for mailbox context or key ownership.
    ///
    /// When specified, identifies a specific user whose mailbox is being accessed or
    /// (for URLAUTH) whose mailbox access key table will authorize the URL.
    public let encodedUser: EncodedUser?

    /// Optional authentication mechanism requirement.
    ///
    /// When specified, indicates either that any appropriate authentication mechanism may be used (`any`),
    /// or that a specific mechanism is required (via ``IMAPURLAuthenticationMechanism/type(_:)``).
    public let authenticationMechanism: IMAPURLAuthenticationMechanism?

    /// Creates a new user and authentication mechanism specification.
    ///
    /// At least one of `encodedUser` or `authenticationMechanism` must be non-nil.
    /// - parameter encodedUser: Optional user identifier. Defaults to `nil`.
    /// - parameter authenticationMechanism: Optional authentication mechanism requirement. Defaults to `nil`.
    public init(encodedUser: EncodedUser?, authenticationMechanism: IMAPURLAuthenticationMechanism?) {
        precondition(encodedUser != nil || authenticationMechanism != nil, "Need one of `encodedUser` or `iAuth`")
        self.encodedUser = encodedUser
        self.authenticationMechanism = authenticationMechanism
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUserAuthenticationMechanism(_ data: UserAuthenticationMechanism) -> Int {
        self.writeIfExists(data.encodedUser) { user in
            self.writeEncodedUser(user)
        }
            + self.writeIfExists(data.authenticationMechanism) { iAuth in
                self.writeIMAPURLAuthenticationMechanism(iAuth)
            }
    }
}
