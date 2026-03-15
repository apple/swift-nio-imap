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

/// Different ways to specify message data to fetch via IMAP URLs.
///
/// This enum provides flexible message fetch specifications for IMAP URLs (RFC 2192/5092)
/// and URLAUTH-authorized fetch operations (RFC 4467). Each case represents a different
/// combination of message location components that can be specified in a URL, allowing
/// for relative paths and partial URL information.
///
/// The fetch type is used in ``URLCommand/fetch(path:authenticatedURL:)`` to specify
/// exactly what message content should be retrieved.
///
/// ### Fetch Variants
///
/// The cases support different levels of path specification, from complete absolute paths
/// (with mailbox reference and UID) to partial paths (UID only, section only, or byte range only).
///
/// ### Examples
///
/// Complete path with mailbox, UID, section, and byte range:
/// ```
/// imap://user@example.com/INBOX/;uidvalidity=100/;uid=20;section=1.2;partial=0.1024
/// ```
///
/// Just UID and section (assumes current mailbox from URL):
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=TEXT
/// ```
///
/// Just section (assumes current mailbox and message):
/// ```
/// imap://user@example.com/INBOX/;section=1
/// ```
///
/// Just byte range (assumes current message):
/// ```
/// imap://user@example.com/INBOX/;partial=512.1024
/// ```
///
/// ## Related Types
///
/// - ``MessagePath`` provides complete message location with mailbox, UID, optional section, and range
/// - ``MailboxUIDValidity`` identifies a mailbox with optional UID validity
/// - ``URLMessageSection`` specifies message sections
/// - ``MessagePath.ByteRange`` specifies byte ranges
/// - ``URLCommand`` uses fetch types in ``URLCommand/fetch(path:authenticatedURL:)``
///
/// - SeeAlso: [RFC 2192 Section 5.2](https://datatracker.ietf.org/doc/html/rfc2192#section-5.2) - IMAP URL ABNF
/// - SeeAlso: [RFC 4467 Section 5](https://datatracker.ietf.org/doc/html/rfc4467#section-5) - Generation of URLAUTH-Authorized URLs
public enum URLFetchType: Hashable, Sendable {
    /// Complete message specification with mailbox reference, UID, optional section, and optional byte range.
    ///
    /// This is the most explicit form, providing all location information in a single
    /// fully-qualified URL path. Useful for creating complete, standalone URLs.
    case refUidSectionPartial(
        ref: MailboxUIDValidity,
        uid: IUID,
        section: URLMessageSection?,
        partial: MessagePath.ByteRange?
    )

    /// Message specification with UID (and optional section and byte range) but no explicit mailbox.
    ///
    /// Assumes the mailbox context is provided separately (e.g., by `SELECT`). Useful
    /// for relative URLs within an already-selected mailbox.
    case uidSectionPartial(uid: IUID, section: URLMessageSection?, partial: MessagePath.ByteRange?)

    /// Section specification (and optional byte range) without explicit UID.
    ///
    /// Assumes both the mailbox and message UID are provided by context. Useful for
    /// specifying parts of an already-identified message.
    case sectionPartial(section: URLMessageSection, partial: MessagePath.ByteRange?)

    /// Byte range specification only.
    ///
    /// Assumes the mailbox, message UID, and section are provided by context. Useful
    /// for specifying portions of an already-identified message section.
    case partialOnly(MessagePath.ByteRange)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLFetchType(_ data: URLFetchType) -> Int {
        switch data {
        case .refUidSectionPartial(ref: let ref, uid: let uid, section: let section, partial: let range):
            return self.writeEncodedMailboxUIDValidity(ref) + self.writeIUIDOnly(uid)
                + self.writeIfExists(section) { section in
                    self.writeString("/") + self.writeURLMessageSectionOnly(section)
                }
                + self.writeIfExists(range) { range in
                    self.writeString("/") + self.writeMessagePathByteRangeOnly(range)
                }
        case .uidSectionPartial(uid: let uid, section: let section, partial: let range):
            return self.writeIUIDOnly(uid)
                + self.writeIfExists(section) { section in
                    self.writeString("/") + self.writeURLMessageSectionOnly(section)
                }
                + self.writeIfExists(range) { range in
                    self.writeString("/") + self.writeMessagePathByteRangeOnly(range)
                }
        case .sectionPartial(section: let section, partial: let partial):
            return self.writeURLMessageSectionOnly(section)
                + self.writeIfExists(partial) { partial in
                    self.writeString("/") + self.writeMessagePathByteRangeOnly(partial)
                }
        case .partialOnly(let partial):
            return self.writeMessagePathByteRangeOnly(partial)
        }
    }
}
