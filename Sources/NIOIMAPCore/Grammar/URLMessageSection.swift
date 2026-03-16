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

/// A percent-encoded message section reference for use in IMAP URL paths.
///
/// Message sections in IMAP (RFC 3501) refer to parts of a message structure using dot-separated
/// numeric notation. When used in IMAP URLs (RFC 2192/5092) and URLAUTH-authorized URLs (RFC 4467),
/// section references are percent-encoded to ensure they contain only URL-safe characters.
///
/// This type wraps a percent-encoded section reference for use in IMAP URL construction.
/// It appears in URL paths as `;SECTION=<section>` (or `/;SECTION=<section>` in some contexts).
///
/// ### Section Reference Format
///
/// Message sections use dot-separated numbers to reference structure parts:
/// - `"1"` - First part of the message body
/// - `"1.2"` - Second subpart of the first part
/// - `"1.2.MIME"` - MIME headers of a specific part
/// - `"TEXT"` - Message body text
/// - `"HEADER"` - Full message headers
/// - `"HEADER.FIELDS (From To Date)"` - Specific header fields
///
/// ### Examples
///
/// Fetch just the first part of a message:
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=1
/// ```
///
/// Fetch the MIME headers of the second subpart:
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=1.2.MIME
/// ```
///
/// Fetch the entire message text (no `HEADER`):
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=TEXT
/// ```
///
/// In a URLAUTH context with section specification:
/// ```
/// C: a001 GENURLAUTH "imap://user@example.com/INBOX/;uid=20;section=1.2;urlauth=anonymous" INTERNAL
/// S: * GENURLAUTH "imap://user@example.com/INBOX/;uid=20;section=1.2;urlauth=anonymous:internal:..."
/// ```
///
/// ## Related Types
///
/// - ``EncodedSection`` wraps the percent-encoded section string
/// - ``MessagePath`` includes an optional ``URLMessageSection``
/// - ``URLFetchType`` may include section specifications
/// - ``SectionSpecifier`` defines RFC 3501 section syntax details
///
/// - SeeAlso: [RFC 2192 Section 5.2](https://datatracker.ietf.org/doc/html/rfc2192#section-5.2) - IMAP URL ABNF
/// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5) - FETCH Command
/// - SeeAlso: [RFC 4467](https://datatracker.ietf.org/doc/html/rfc4467) - IMAP URLAUTH Extension
public struct URLMessageSection: Hashable, Sendable {
    /// The percent-encoded message section reference.
    ///
    /// Contains only URL-safe ASCII characters. Section references with non-ASCII or special
    /// characters are percent-encoded according to RFC 3986 using UTF-8.
    public var encodedSection: EncodedSection

    /// Creates a new message section reference for use in URLs.
    /// - parameter encodedSection: The percent-encoded section reference.
    public init(encodedSection: EncodedSection) {
        self.encodedSection = encodedSection
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLMessageSection(_ section: URLMessageSection) -> Int {
        self.writeString("/;SECTION=\(section.encodedSection.section)")
    }

    @discardableResult mutating func writeURLMessageSectionOnly(_ section: URLMessageSection) -> Int {
        self.writeString(";SECTION=\(section.encodedSection.section)")
    }
}
