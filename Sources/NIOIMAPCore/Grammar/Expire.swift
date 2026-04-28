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

/// An expiration date and time for a URLAUTH-authorized IMAP URL.
///
/// When specified as part of a ``AuthenticatedURLRump``, this restricts how long a URLAUTH-authorized URL
/// remains valid. After the expiration date and time, the IMAP server must reject the URL
/// (RFC 4467 Section 3).
///
/// An optional component appended to IMAP URLs as `;EXPIRE=<datetime>` (in RFC 3339 format).
/// If not specified, the URL has no expiration time, though it can still be revoked by other means
/// (such as regenerating the mailbox access key).
///
/// ### Example
///
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;expire=2025-12-31T23:59:59Z;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;expire=2025-12-31T23:59:59Z;urlauth=anonymous:internal:..."
/// ```
///
/// The `;expire=2025-12-31T23:59:59Z` component indicates the URL expires at that date and time.
///
/// ## Related types
///
/// See ``AuthenticatedURLRump`` for how expiration is combined with ``Access`` identifiers,
/// and ``FullDateTime`` for the datetime format specification.
///
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
public struct Expire: Hashable, Sendable {
    /// The latest date and time that a URLAUTH-authorized URL is valid.
    ///
    /// After this date and time, the URL must be rejected by the IMAP server. The datetime is
    /// encoded in RFC 3339 format (for example, `2025-12-31T23:59:59Z`).
    public var dateTime: FullDateTime

    /// Creates a new expiration date and time.
    /// - parameter dateTime: The latest date and time that an IMAP URL is valid.
    public init(dateTime: FullDateTime) {
        self.dateTime = dateTime
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExpire(_ data: Expire) -> Int {
        self.writeString(";EXPIRE=") + self.writeFullDateTime(data.dateTime)
    }
}
