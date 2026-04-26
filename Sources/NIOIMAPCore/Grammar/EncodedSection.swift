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

/// A percent-encoded message section reference for use in IMAP URLs.
///
/// IMAP message sections (as defined in RFC 3501) specify parts of message structures
/// using dot-separated numeric notation (for example, "1", "1.2", or "1.2.3"). When used in IMAP URLs,
/// section references are percent-encoded to ensure URL safety (RFC 2192, RFC 3986).
///
/// Wraps a percent-encoded section reference for use in URL construction.
/// The encoded string contains only ASCII-safe characters and can be safely included in IMAP URL syntax.
///
/// ### Example
///
/// A section reference like "1.2.MIME" (the MIME headers of the second part of the first part)
/// would be percent-encoded in an IMAP URL:
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=1.2.MIME
/// ```
///
/// In a message path structure:
/// ```
/// MessagePath(
///   mailboxReference: MailboxUIDValidity(...),
///   iUID: IUID(uid: UID(100)),
///   section: URLMessageSection(
///     encodedSection: EncodedSection(section: "1.2.MIME")
///   )
/// )
/// ```
///
/// ## Related types
///
/// See ``URLMessageSection`` for the complete message section specification,
/// ``MessagePath`` for the full message location including sections, and
/// ``SectionSpecifier`` for RFC 3501 section syntax details.
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5) - FETCH Command
/// - SeeAlso: [RFC 3986](https://datatracker.ietf.org/doc/html/rfc3986) - URI Generic Syntax (percent-encoding)
public struct EncodedSection: Hashable, Sendable {
    /// The percent-encoded message section reference.
    ///
    /// Contains only URL-safe ASCII characters. Section references with non-ASCII or special
    /// characters are percent-encoded according to RFC 3986 using UTF-8.
    public var section: String

    /// Creates a new percent-encoded message section reference.
    /// - parameter section: The percent-encoded section reference string.
    public init(section: String) {
        self.section = section
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedSection(_ section: EncodedSection) -> Int {
        self.writeString(section.section)
    }
}
