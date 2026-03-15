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

/// A message attribute that can be retrieved using the `FETCH` command (RFC 3501 and extensions).
///
/// The `FETCH` command allows clients to retrieve specific attributes of messages from the server.
/// This enum represents all available fetch attributes, including standard RFC 3501 attributes and
/// attributes from various IMAP extensions.
///
/// ### Standard Attributes (RFC 3501)
///
/// Basic message properties like envelope, flags, internal date, and RFC 822 message format.
///
/// ### Extension Attributes
///
/// - `BODYSTRUCTURE`: Detailed message structure information (RFC 3501)
/// - `BINARY`: Raw binary content of message sections (RFC 3516 BINARY extension)
/// - `MODSEQ`: Modification sequence tracking (RFC 7162 CONDSTORE extension)
/// - `PREVIEW`: Server-generated message preview (RFC 8970)
/// - `EMAILID` / `THREADID`: Message and thread identifiers (RFC 8474)
/// - `X-GM-*`: Gmail-specific attributes (non-standard)
///
/// ### Attributes with Options
///
/// Some attributes support optional parameters:
/// - ``bodySection(peek:_:_:)`` supports a `peek` flag (prevents \\Seen flag modification) and partial byte ranges
/// - ``binary(peek:section:partial:)`` supports peek mode and partial byte ranges
/// - ``bodyStructure(extensions:)`` controls whether extension fields are included
/// - ``preview(lazy:)`` supports lazy evaluation of preview text
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (ENVELOPE FLAGS INTERNALDATE)
/// S: * 1 FETCH (ENVELOPE (...) FLAGS (\\Seen) INTERNALDATE "17-Jul-1996 09:01:33 -0700")
/// S: A001 OK FETCH completed
/// ```
///
/// The `ENVELOPE`, `FLAGS`, and `INTERNALDATE` in the FETCH command correspond to ``envelope``,
/// ``flags``, and ``internalDate`` cases respectively.
///
/// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
public enum FetchAttribute: Hashable, Sendable {
    /// The message envelope structure containing sender, recipient, subject, and date information.
    ///
    /// Returns an ``Envelope`` structure with the sender, recipient lists, subject, and other message metadata.
    /// This is a parsed representation of the message headers.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case envelope

    /// The message flags currently set on this message.
    ///
    /// Returns a list of flags (both standard flags like `\Seen` and custom keywords).
    /// See ``Flag`` for flag types.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case flags

    /// The internal date of the message (when the message was received by the server).
    ///
    /// Returns a ``ServerMessageDate`` representing the server's timestamp for when the message
    /// entered the mailbox.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case internalDate

    /// The entire message in RFC 822 format (includes headers and body).
    ///
    /// Returns the complete message as a single binary string in RFC 822 format. Note that this returns
    /// the message in RFC 822 syntax rather than the IMAP-specific BODY format.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case rfc822

    /// The RFC 822 headers of the message (without the body).
    ///
    /// Functionally equivalent to ``bodySection(peek:_:_:)`` with `peek: true` and `.header`,
    /// but returns the headers in RFC 822 format rather than IMAP BODY format.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case rfc822Header

    /// The size of the message in bytes, as counted using the RFC 822 definition.
    ///
    /// Returns the byte count of the message in RFC 822 format. This may differ slightly
    /// from the actual message size due to line-ending conventions.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case rfc822Size

    /// The RFC 822 message body (text portion, excluding headers).
    ///
    /// Functionally equivalent to ``bodySection(peek:_:_:)`` with `peek: false` and `.text`,
    /// but returns the body in RFC 822 format rather than IMAP BODY format.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case rfc822Text

    /// The message structure (BODY or BODYSTRUCTURE).
    ///
    /// Returns a hierarchical structure of the message's MIME parts. When `extensions: true`,
    /// returns the full BODYSTRUCTURE including extension information; otherwise returns
    /// the basic BODY structure.
    ///
    /// - parameter extensions: If `true`, includes extension fields (BODYSTRUCTURE); if `false`, omits them (BODY)
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case bodyStructure(extensions: Bool)

    /// A specific section of the message body (headers, text, MIME parts, or entire message).
    ///
    /// Allows fetching of specific parts of the message, including individual MIME parts and
    /// their headers. Supports partial byte ranges for efficient fetching of large parts.
    ///
    /// - parameter peek: If `true`, does not set the `\Seen` flag on the message; if `false`, sets `\Seen`
    /// - parameter section: The section specifier (e.g., `1`, `1.1`, `HEADER`, `TEXT`)
    /// - parameter partial: Optional byte range `startOctet..<endOctet` to fetch only a portion
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case bodySection(peek: Bool, _ section: SectionSpecifier, ClosedRange<UInt32>?)

    /// The unique identifier (UID) of the message.
    ///
    /// Returns the message's UID, which is stable across sessions and not affected by message
    /// deletions or mailbox state changes (unless the UIDVALIDITY changes).
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case uid

    /// The modification sequence value of the message (CONDSTORE extension).
    ///
    /// Returns a marker indicating that the MODSEQ fetch attribute is present, but the actual
    /// mod-sequence value is returned separately. This is less common than ``modificationSequenceValue(_:)``.
    ///
    /// **Requires server capability:** ``Capability/condStore``
    ///
    /// - SeeAlso: [RFC 7162 Section 3.1.4](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.4)
    case modificationSequence

    /// The modification sequence value of the message with a specific value (CONDSTORE extension).
    ///
    /// When used with a conditional FETCH modifier like `CHANGEDSINCE`, the server returns the
    /// actual mod-sequence value of the message.
    ///
    /// **Requires server capability:** ``Capability/condStore``
    ///
    /// - parameter value: The specific modification sequence value to fetch
    /// - SeeAlso: [RFC 7162 Section 3.1.4](https://datatracker.ietf.org/doc/html/rfc7162#section-3.1.4)
    case modificationSequenceValue(ModificationSequenceValue)

    /// Raw binary data of a specific message section (BINARY extension).
    ///
    /// Like ``bodySection(peek:_:_:)`` but returns raw binary data instead of IMAP-formatted body data.
    /// Supports partial byte ranges for efficient fetching.
    ///
    /// **Requires server capability:** ``Capability/binary``
    ///
    /// - parameter peek: If `true`, does not set the `\Seen` flag; if `false`, sets `\Seen`
    /// - parameter section: The specific MIME part to fetch (e.g., `1`, `1.1`)
    /// - parameter partial: Optional byte range to fetch only a portion
    /// - SeeAlso: [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516)
    case binary(peek: Bool, section: SectionSpecifier.Part, partial: ClosedRange<UInt32>?)

    /// The size of a specific message section in bytes (BINARY extension).
    ///
    /// Returns only the byte count of the specified section, without the actual data.
    ///
    /// **Requires server capability:** ``Capability/binary``
    ///
    /// - parameter section: The specific MIME part whose size to fetch
    /// - SeeAlso: [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516)
    case binarySize(section: SectionSpecifier.Part)

    /// The message's Gmail-assigned message ID (Gmail extension, non-standard).
    ///
    /// This is a Gmail-specific extension that returns the unique message identifier within
    /// Gmail's system. Not part of the IMAP standard.
    ///
    /// - SeeAlso:  https://developers.google.com/gmail/imap/imap-extensions
    case gmailMessageID

    /// The message's Gmail thread ID (Gmail extension, non-standard).
    ///
    /// This is a Gmail-specific extension that returns the identifier for the thread/conversation
    /// this message belongs to. Not part of the IMAP standard.
    ///
    /// - SeeAlso:  https://developers.google.com/gmail/imap/imap-extensions
    case gmailThreadID

    /// The message's Gmail labels (Gmail extension, non-standard).
    ///
    /// This is a Gmail-specific extension that returns the list of labels (like folders) applied
    /// to this message. Not part of the IMAP standard.
    ///
    /// - SeeAlso:  https://developers.google.com/gmail/imap/imap-extensions
    case gmailLabels

    /// A server-generated preview of the message content (RFC 8970).
    ///
    /// Returns a brief excerpt of the message content, useful for displaying message previews
    /// without fetching the full message body.
    ///
    /// **Requires server capability:** ``Capability/preview``
    ///
    /// - parameter lazy: If `true`, server may delay generating the preview; if `false`, must be available immediately
    /// - SeeAlso: [RFC 8970](https://datatracker.ietf.org/doc/html/rfc8970)
    case preview(lazy: Bool)

    /// The message's email ID (RFC 8474 OBJECTID extension).
    ///
    /// Returns a stable, unique identifier for the message that persists across mailbox
    /// reorganizations. Different from UID, which can change if the mailbox is reconstructed.
    ///
    /// **Requires server capability:** ``Capability/objectID``
    ///
    /// - SeeAlso: [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)
    case emailID

    /// The message's thread ID (RFC 8474 OBJECTID extension).
    ///
    /// Returns a stable identifier for the conversation/thread this message belongs to.
    /// Messages with the same thread ID are part of the same conversation.
    ///
    /// **Requires server capability:** ``Capability/objectID``
    ///
    /// - SeeAlso: [RFC 8474](https://datatracker.ietf.org/doc/html/rfc8474)
    case threadID
}

extension Array where Element == FetchAttribute {
    /// Macro equivalent to `[.flags, .internalDate, .rfc822Size, envelope]`
    public static let all: [Element] = [.flags, .internalDate, .rfc822Size, .envelope]

    /// Macro equivalent to `[.flags, .internalDate, .rfc822Size]`
    public static let fast: [Element] = [.flags, .internalDate, .rfc822Size]

    /// Macro equivalent to `[.flags, .internalDate, .rfc822Size, envelope, body]`
    public static let full: [Element] = [
        .flags, .internalDate, .rfc822Size, .envelope, .bodyStructure(extensions: false),
    ]
}

// MARK: - Encoding

extension FetchAttribute: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeFetchAttribute(self)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchAttributeList(_ atts: [FetchAttribute]) -> Int {
        // FAST -> (FLAGS INTERNALDATE RFC822.SIZE)
        // ALL -> (FLAGS INTERNALDATE RFC822.SIZE ENVELOPE)
        // FULL -> (FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODY)
        if atts.contains(.flags), atts.contains(.internalDate) {
            if atts.count == 3, atts.contains(.rfc822Size) {
                return self.writeString("FAST")
            }
            if atts.count == 4, atts.contains(.rfc822Size), atts.contains(.envelope) {
                return self.writeString("ALL")
            }
            if atts.count == 5, atts.contains(.rfc822Size), atts.contains(.envelope),
                atts.contains(.bodyStructure(extensions: false))
            {
                return self.writeString("FULL")
            }
        }

        return self.writeArray(atts) { (element, self) in
            self.writeFetchAttribute(element)
        }
    }

    @discardableResult mutating func writeFetchAttribute(_ attribute: FetchAttribute) -> Int {
        switch attribute {
        case .envelope:
            return self.writeFetchAttribute_envelope()
        case .flags:
            return self.writeFetchAttribute_flags()
        case .internalDate:
            return self.writeFetchAttribute_internalDate()
        case .rfc822:
            return self.writeFetchAttribute_rfc822()
        case .rfc822Size:
            return self.writeFetchAttribute_rfc822Size()
        case .rfc822Header:
            return self.writeFetchAttribute_rfc822Header()
        case .rfc822Text:
            return self.writeFetchAttribute_rfc822Text()
        case .bodyStructure(extensions: let extensions):
            return self.writeFetchAttribute_bodyStructure(extensions: extensions)
        case .bodySection(peek: let peek, let section, let partial):
            return self.writeFetchAttribute_body(peek: peek, section: section, partial: partial)
        case .uid:
            return self.writeFetchAttribute_uid()
        case .modificationSequenceValue(let value):
            return self.writeModificationSequenceValue(value)
        case .binary(let peek, let section, let partial):
            return self.writeFetchAttribute_binary(peek: peek, section: section, partial: partial)
        case .binarySize(let section):
            return self.writeFetchAttribute_binarySize(section)
        case .modificationSequence:
            return self.writeString("MODSEQ")
        case .gmailMessageID:
            return self.writeFetchAttribute_gmailMessageID()
        case .gmailThreadID:
            return self.writeFetchAttribute_gmailThreadID()
        case .gmailLabels:
            return self.writeFetchAttribute_gmailLabels()
        case .preview(let lazy):
            return self.writeFetchAttribute_preview(lazy)
        case .emailID:
            return self.writeFetchAttribute_emailID()
        case .threadID:
            return self.writeFetchAttribute_threadID()
        }
    }

    @discardableResult mutating func writeFetchAttribute_envelope() -> Int {
        self.writeString("ENVELOPE")
    }

    @discardableResult mutating func writeFetchAttribute_flags() -> Int {
        self.writeString("FLAGS")
    }

    @discardableResult mutating func writeFetchAttribute_internalDate() -> Int {
        self.writeString("INTERNALDATE")
    }

    @discardableResult mutating func writeFetchAttribute_uid() -> Int {
        self.writeString("UID")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822() -> Int {
        self.writeString("RFC822")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822Size() -> Int {
        self.writeString("RFC822.SIZE")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822Header() -> Int {
        self.writeString("RFC822.HEADER")
    }

    @discardableResult mutating func writeFetchAttribute_rfc822Text() -> Int {
        self.writeString("RFC822.TEXT")
    }

    @discardableResult mutating func writeFetchAttribute_preview(_ lazy: Bool) -> Int {
        self.writeString(lazy ? "PREVIEW (LAZY)" : "PREVIEW")
    }

    @discardableResult mutating func writeFetchAttribute_bodyStructure(extensions: Bool) -> Int {
        self.writeString(extensions ? "BODYSTRUCTURE" : "BODY")
    }

    @discardableResult mutating func writeFetchAttribute_body(
        peek: Bool,
        section: SectionSpecifier?,
        partial: ClosedRange<UInt32>?
    ) -> Int {
        self.writeString(peek ? "BODY.PEEK" : "BODY") + self.writeSection(section)
            + self.writeIfExists(partial) { (partial) -> Int in
                self.writeByteRange(partial)
            }
    }

    @discardableResult mutating func writeFetchAttribute_binarySize(_ section: SectionSpecifier.Part) -> Int {
        self.writeString("BINARY.SIZE") + self.writeSectionBinary(section)
    }

    @discardableResult mutating func writeFetchAttribute_binary(
        peek: Bool,
        section: SectionSpecifier.Part,
        partial: ClosedRange<UInt32>?
    ) -> Int {
        self.writeString("BINARY")
            + self.write(if: peek) {
                self.writeString(".PEEK")
            } + self.writeSectionBinary(section)
            + self.writeIfExists(partial) { (partial) -> Int in
                self.writeByteRange(partial)
            }
    }

    @discardableResult mutating func writeFetchAttribute_gmailMessageID() -> Int {
        self.writeString("X-GM-MSGID")
    }

    @discardableResult mutating func writeFetchAttribute_gmailThreadID() -> Int {
        self.writeString("X-GM-THRID")
    }

    @discardableResult mutating func writeFetchAttribute_gmailLabels() -> Int {
        self.writeString("X-GM-LABELS")
    }

    @discardableResult mutating func writeFetchAttribute_emailID() -> Int {
        return writeString("EMAILID")
    }

    @discardableResult mutating func writeFetchAttribute_threadID() -> Int {
        return writeString("THREADID")
    }
}
