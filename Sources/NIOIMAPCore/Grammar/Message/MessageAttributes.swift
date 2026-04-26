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

/// Individual message attributes returned in a `FETCH` response.
///
/// When a client sends a `FETCH` command, the server responds with one or more message attributes for each matching message.
/// Each ``MessageAttribute`` represents a single piece of message data, such as flags, message structure, or message identifiers.
/// Multiple attributes are returned together in a single `FETCH` response line.
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (FLAGS ENVELOPE UID)
/// S: * 1 FETCH (FLAGS (\Seen) ENVELOPE (...) UID 123)
/// ```
///
/// The response line contains three attributes: ``flags(_:)`` wrapping `\Seen`, ``envelope(_:)`` containing the message envelope,
/// and ``uid(_:)`` with UID `123`.
///
/// ## Request versus response
///
/// Use ``FetchAttribute`` to request specific message attributes in a `FETCH` command. The server responds with ``MessageAttribute``
/// values containing the requested data. Not all ``FetchAttribute`` cases have corresponding ``MessageAttribute`` cases — for example,
/// ``FetchAttribute/bodyStructure(extensions:)`` (a request) produces ``body(_:hasExtensionData:)`` (response).
///
/// ## Related types
///
/// - ``FetchAttribute`` — Request side (what the client asks for)
/// - ``FetchModifier`` — Modifiers for `FETCH` commands (RFC 7162)
/// - ``SectionSpecifier`` — Specifies message body sections for partial fetches
/// - ``StreamingKind`` — Streaming body section references
///
/// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
public enum MessageAttribute: Hashable, Sendable {
    /// The message flags.
    ///
    /// The `FLAGS` attribute contains a list of zero or more flags set for this message.
    /// Each flag is a ``Flag`` which may be a standard system flag (like `\Seen`, `\Flagged`) or a custom keyword.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (FLAGS (\Seen \Flagged))
    /// ```
    ///
    /// The response contains the ``flags(_:)`` case with two system flags.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case flags([Flag])

    /// The message envelope (RFC 2822 headers in structured format).
    ///
    /// The `ENVELOPE` attribute contains structured information about the message headers, including sender, recipients,
    /// subject, dates, and identifiers. See ``Envelope`` for field descriptions.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (ENVELOPE (“date” “from” “subject” “to” “cc” “bcc” “in-reply-to” “message-id”))
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case envelope(Envelope)

    /// The internal date of the message (when the server received it).
    ///
    /// The `INTERNALDATE` attribute contains the date and time the server received the message. This differs from
    /// the message’s `Date` header, which the client provided when sending the message.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (INTERNALDATE “27-Mar-2023 12:34:56 +0000”)
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case internalDate(ServerMessageDate)

    /// The unique message identifier.
    ///
    /// The `UID` attribute contains the unique identifier assigned by the server to this message. UIDs are persistent
    /// across connections and remain constant unless the server resets the mailbox (changing ``UIDValidity``).
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (UID 12345)
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 2.3.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.1)
    case uid(UID)

    /// The size of the message in octets (bytes).
    ///
    /// The `RFC822.SIZE` attribute contains the number of octets in the message as defined by RFC 2822,
    /// including all headers and body content.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (RFC822.SIZE 1234)
    /// ```
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case rfc822Size(Int)

    /// The message body structure (MIME parts).
    ///
    /// The `BODY` or `BODYSTRUCTURE` attribute contains a description of the message’s MIME body structure,
    /// including multipart boundaries and content type information for each part.
    ///
    /// When `hasExtensionData` is `true`, the attribute was returned as `BODYSTRUCTURE` (RFC 3501 extension data included).
    /// When `false`, it was returned as `BODY` (basic structure only).
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (BODY ((“TEXT” “PLAIN” NIL NIL NIL “7BIT” 1234 50)))
    /// S: * 2 FETCH (BODYSTRUCTURE ((“TEXT” “PLAIN” NIL NIL NIL “7BIT” 1234 50 NIL NIL NIL NIL)))
    /// ```
    ///
    /// The first uses `BODY` (basic), the second uses `BODYSTRUCTURE` (with extension fields).
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case body(BodyStructure, hasExtensionData: Bool)

    /// The size of a specific body section after transfer encoding removal.
    ///
    /// The `BINARY.SIZE[section]` attribute contains the byte count of the specified message section after removing
    /// any `Content-Transfer-Encoding` applied to the section. This is useful for determining the decoded size of a part
    /// without downloading its full content.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (BINARY.SIZE[2] 5000)
    /// ```
    ///
    /// Indicates body part 2 has 5000 octets when decoded.
    ///
    /// - SeeAlso: [RFC 3516 IMAP4 Binary Content Extension](https://datatracker.ietf.org/doc/html/rfc3516)
    case binarySize(section: SectionSpecifier.Part, size: Int)

    /// A nil response to a requested body section.
    ///
    /// The `NIL` attribute indicates that the server could not return the requested body section because the section
    /// does not exist in the message. This differs from a zero-length section, which would be returned as a literal
    /// with byte count 0.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (BODY[4.TEXT] NIL)
    /// ```
    ///
    /// Indicates that body part 4 has no TEXT section (it doesn’t exist).
    ///
    /// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
    case nilBody(StreamingKind)

    /// The modification sequence number for the message.
    ///
    /// The `MODSEQ` attribute contains a modification sequence number indicating when the message or its flags last changed.
    /// Used with the `CONDSTORE` extension for efficient synchronization.
    ///
    /// - SeeAlso: [RFC 7162 IMAP4 Extensions: CONDSTORE and QRESYNC](https://datatracker.ietf.org/doc/html/rfc7162)
    case fetchModificationSequence(ModificationSequenceValue)

    /// Gmail-specific message unique identifier (vendor extension).
    ///
    /// The `X-GM-MSGID` attribute contains a Gmail-specific unique message ID that remains stable across mailboxes.
    /// A 64-bit unsigned integer and Gmail-only extension, not part of the standard IMAP protocol.
    ///
    /// For standard IMAP object identifiers, see ``emailID(_:)`` which uses RFC 8474.
    ///
    /// - SeeAlso: [Gmail IMAP Extensions](https://developers.google.com/gmail/imap/imap-extensions)
    case gmailMessageID(UInt64)

    /// Gmail-specific thread identifier (vendor extension).
    ///
    /// The `X-GM-THRID` attribute contains a Gmail-specific thread ID that associates messages belonging to the same thread.
    /// A 64-bit unsigned integer and Gmail-only extension, not part of the standard IMAP protocol.
    ///
    /// For standard IMAP object identifiers, see ``threadID(_:)`` which uses RFC 8474.
    ///
    /// - SeeAlso: [Gmail IMAP Extensions](https://developers.google.com/gmail/imap/imap-extensions)
    case gmailThreadID(UInt64)

    /// Gmail-specific message labels (vendor extension).
    ///
    /// The `X-GM-LABELS` attribute contains a list of labels (tags) applied to the message in Gmail. Each label is a ``GmailLabel``.
    /// A Gmail-only extension, not part of the standard IMAP protocol.
    ///
    /// - SeeAlso: [Gmail IMAP Extensions](https://developers.google.com/gmail/imap/imap-extensions)
    case gmailLabels([GmailLabel])

    /// Server-generated preview text of the message.
    ///
    /// The `PREVIEW` attribute contains an abbreviated text representation of the message body that the server generates
    /// automatically. This is useful for displaying message previews without downloading full message bodies.
    /// The value may be `nil` if the server could not generate a preview.
    ///
    /// - SeeAlso: [RFC 8970 IMAP4 Extension: Message Preview Generation](https://datatracker.ietf.org/doc/html/rfc8970)
    case preview(PreviewText?)

    /// An object identifier for the message content.
    ///
    /// The `EMAILID` attribute contains an object identifier that uniquely identifies the message’s content.
    /// Stable across servers and can be used to detect when a message with the same content exists
    /// in different mailboxes or on different servers.
    ///
    /// For Gmail-specific message identifiers, see ``gmailMessageID(_:)`` which uses the `X-GM-MSGID` extension.
    ///
    /// - SeeAlso: [RFC 8474 IMAP4 Extension: OBJECTID](https://datatracker.ietf.org/doc/html/rfc8474)
    case emailID(EmailID)

    /// An object identifier for the message thread.
    ///
    /// The `THREADID` attribute contains an object identifier for the thread the message belongs to.
    /// `nil` if the message is not part of a thread or if the server does not support threading.
    ///
    /// For Gmail-specific thread identifiers, see ``gmailThreadID(_:)`` which uses the `X-GM-THRID` extension.
    ///
    /// - SeeAlso: [RFC 8474 IMAP4 Extension: OBJECTID](https://datatracker.ietf.org/doc/html/rfc8474)
    case threadID(ThreadID?)
}

extension MessageAttribute: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeMessageAttribute(self)
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageAttributes(_ atts: [MessageAttribute]) -> Int {
        self.writeArray(atts) { (element, self) in
            self.writeMessageAttribute(element)
        }
    }

    @discardableResult mutating func writeMessageAttribute(_ type: MessageAttribute) -> Int {
        switch type {
        case .envelope(let env):
            return self.writeMessageAttribute_envelope(env)
        case .internalDate(let date):
            return self.writeMessageAttribute_internalDate(date)
        case .rfc822Size(let size):
            return self.writeString("RFC822.SIZE \(size)")
        case .body(let body, hasExtensionData: let hasExtensionData):
            return self.writeMessageAttribute_body(body, hasExtensionData: hasExtensionData)
        case .uid(let uid):
            return self.writeString("UID \(uid.rawValue)")
        case .binarySize(section: let section, size: let number):
            return self.writeMessageAttribute_binarySize(section: section, number: number)
        case .flags(let flags):
            return self.writeMessageAttributeFlags(flags)
        case .nilBody(let kind):
            return self.writeMessageAttributeNilBody(kind)
        case .fetchModificationSequence(let val):
            return self.writeString("MODSEQ (") + self.writeModificationSequenceValue(val) + self.writeString(")")
        case .gmailMessageID(let id):
            return self.writeMessageAttribute_gmailMessageID(id)
        case .gmailThreadID(let id):
            return self.writeMessageAttribute_gmailThreadID(id)
        case .gmailLabels(let labels):
            return self.writeMessageAttribute_gmailLabels(labels)
        case .preview(let previewText):
            return self.writeMessageAttribute_preview(previewText)
        case .emailID(let id):
            return self.writeMessageAttribute_emailID(id)
        case .threadID(let id):
            return self.writeMessageAttribute_threadID(id)
        }
    }

    @discardableResult mutating func writeMessageAttribute_binarySize(
        section: SectionSpecifier.Part,
        number: Int
    ) -> Int {
        self.writeString("BINARY.SIZE") + self.writeSectionBinary(section) + self.writeString(" \(number)")
    }

    @discardableResult mutating func writeMessageAttributeFlags(_ atts: [Flag]) -> Int {
        self.writeString("FLAGS ")
            + self.writeArray(atts) { (element, self) in
                self.writeFlag(element)
            }
    }

    @discardableResult mutating func writeMessageAttributeNilBody(_ kind: StreamingKind) -> Int {
        self.writeStreamingKind(kind) + self.writeSpace() + self.writeNil()
    }

    @discardableResult mutating func writeMessageAttribute_envelope(_ env: Envelope) -> Int {
        self.writeString("ENVELOPE ") + self.writeEnvelope(env)
    }

    @discardableResult mutating func writeMessageAttribute_internalDate(_ date: ServerMessageDate) -> Int {
        self.writeString("INTERNALDATE ") + self.writeInternalDate(date)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822(_ string: ByteBuffer?) -> Int {
        self.writeString("RFC822") + self.writeSpace() + self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822Text(_ string: ByteBuffer?) -> Int {
        self.writeString("RFC822.TEXT") + self.writeSpace() + self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_rfc822Header(_ string: ByteBuffer?) -> Int {
        self.writeString("RFC822.HEADER") + self.writeSpace() + self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_body(
        _ body: MessageAttribute.BodyStructure,
        hasExtensionData: Bool
    ) -> Int {
        self.writeString("BODY")
            + self.write(if: hasExtensionData) { () -> Int in
                self.writeString("STRUCTURE")
            } + self.writeSpace() + self.writeBody(body)
    }

    @discardableResult mutating func writeMessageAttribute_bodySection(
        _ section: SectionSpecifier?,
        number: Int?,
        string: ByteBuffer?
    ) -> Int {
        self.writeString("BODY") + self.writeSection(section)
            + self.writeIfExists(number) { (number) -> Int in
                self.writeString("<\(number)>")
            } + self.writeSpace() + self.writeNString(string)
    }

    @discardableResult mutating func writeMessageAttribute_bodySectionText(number: Int?, size: Int) -> Int {
        self.writeString("BODY[TEXT]")
            + self.writeIfExists(number) { (number) -> Int in
                self.writeString("<\(number)>")
            } + self.writeString(" {\(size)}\r\n")
    }

    @discardableResult mutating func writeMessageAttribute_gmailMessageID(_ id: UInt64) -> Int {
        self.writeString("X-GM-MSGID \(id)")
    }

    @discardableResult mutating func writeMessageAttribute_gmailThreadID(_ id: UInt64) -> Int {
        self.writeString("X-GM-THRID \(id)")
    }

    @discardableResult mutating func writeMessageAttribute_gmailLabels(_ labels: [GmailLabel]) -> Int {
        self.writeString("X-GM-LABELS") + self.writeSpace()
            + self.writeArray(labels) { label, buffer in
                buffer.writeGmailLabel(label)
            }
    }

    @discardableResult mutating func writeMessageAttribute_preview(_ previewText: PreviewText?) -> Int {
        self.writeString("PREVIEW") + self.writeSpace() + self.writeNString(previewText.map { String($0) })
    }

    @discardableResult mutating func writeMessageAttribute_emailID(_ id: EmailID) -> Int {
        self.writeString("EMAILID (") + self.writeEmailID(id) + self.writeString(")")
    }

    @discardableResult mutating func writeMessageAttribute_threadID(_ id: ThreadID?) -> Int {
        if let id {
            self.writeString("THREADID (") + self.writeThreadID(id) + self.writeString(")")
        } else {
            self.writeString("THREADID NIL")
        }
    }
}
