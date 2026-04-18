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

/// The parsed envelope structure of a message, extracted from the message headers (RFC 3501).
///
/// The envelope represents the structured header fields of an email message, including the sender,
/// recipients, subject, date, and message identifiers. When a client fetches the `ENVELOPE` attribute,
/// the server returns this parsed structure rather than raw header data.
///
/// The envelope may contain empty or `nil` values for any field, including completely empty envelopes,
/// though this is rare in practice. All address lists use ``EmailAddressListElement`` to support both
/// individual addresses and address groups.
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (ENVELOPE)
/// S: * 1 FETCH (ENVELOPE ("Mon, 7 Feb 1994 21:52:25 -0800" "The Subject" (("John Doe" NIL "john" "example.com")) (("John Doe" NIL "john" "example.com")) (("John Doe" NIL "john" "example.com")) (("Jane Smith" NIL "jane" "example.com")) ((NIL NIL "info" "example.com")) (("Bob Johnson" NIL "bob" "example.com")) (("Bob Johnson" NIL "bob" "example.com")) NIL NIL "<12345@example.com>"))
/// S: A001 OK FETCH completed
/// ```
///
/// The `ENVELOPE(...)` response is parsed into an ``Envelope`` struct with fields corresponding to each position:
/// date, subject, from, sender, reply-to, to, cc, bcc, in-reply-to, and message-id.
///
/// - SeeAlso: [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2)
/// - SeeAlso: ``FetchAttribute/envelope``
public struct Envelope: Hashable, Sendable {
    /// The date the message was originally written, as parsed from the `Date:` header.
    public var date: InternetMessageDate?

    /// The subject line of the message, as from the `Subject:` header.
    public var subject: ByteBuffer?

    /// The sender(s) of the message, as from the `From:` header.
    ///
    /// This is the author or originator of the message content. Multiple addresses indicate
    /// multiple authors are credited with writing the message.
    public var from: [EmailAddressListElement]

    /// The actual sender on behalf of the author, as from the `Sender:` header.
    ///
    /// This is used when one entity sends a message on behalf of another (e.g., an assistant
    /// sending mail on behalf of their boss). If absent, the `from` field should be used.
    public var sender: [EmailAddressListElement]

    /// The address(es) to which replies should be sent, as from the `Reply-To:` header.
    ///
    /// When present, replies to this message should be sent to this address rather than to
    /// the message's sender or author.
    public var reply: [EmailAddressListElement]

    /// The primary recipient(s) of the message, as from the `To:` header.
    public var to: [EmailAddressListElement]

    /// The carbon-copy recipient(s) of the message, as from the `Cc:` header.
    ///
    /// Recipients listed here are sent a copy of the message, and their addresses are visible
    /// to all recipients.
    public var cc: [EmailAddressListElement]

    /// The blind-carbon-copy recipient(s) of the message, as from the `Bcc:` header.
    ///
    /// Recipients listed here are sent a copy of the message, but their addresses are hidden
    /// from other recipients. Note that the `Bcc:` header is typically not present in the
    /// received message, so this field is often empty.
    public var bcc: [EmailAddressListElement]

    /// The message ID of the message this message is replying to, as from the `In-Reply-To:` header.
    ///
    /// This field links this message to a previous message in a conversation thread.
    public var inReplyTo: MessageID?

    /// The unique message identifier, as from the `Message-ID:` header.
    ///
    /// This identifier is assigned by the originating SMTP server and is globally unique
    /// for the originating system.
    public var messageID: MessageID?

    /// Creates a new envelope.
    /// - parameter date: The date the message was written
    /// - parameter subject: The subject line of the message
    /// - parameter from: The author(s) of the message
    /// - parameter sender: The actual sender (if different from the author)
    /// - parameter reply: The reply-to address(es)
    /// - parameter to: The primary recipient(s)
    /// - parameter cc: The carbon-copy recipient(s)
    /// - parameter bcc: The blind-carbon-copy recipient(s)
    /// - parameter inReplyTo: The message ID this message replies to
    /// - parameter messageID: The unique message identifier
    public init(
        date: InternetMessageDate?,
        subject: ByteBuffer?,
        from: [EmailAddressListElement],
        sender: [EmailAddressListElement],
        reply: [EmailAddressListElement],
        to: [EmailAddressListElement],
        cc: [EmailAddressListElement],
        bcc: [EmailAddressListElement],
        inReplyTo: MessageID?,
        messageID: MessageID?
    ) {
        self.date = date
        self.subject = subject
        self.from = from
        self.sender = sender
        self.reply = reply
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.inReplyTo = inReplyTo
        self.messageID = messageID
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEnvelopeAddresses(_ addresses: [EmailAddressListElement]) -> Int {
        guard addresses.count > 0 else {
            return self.writeNil()
        }

        return
            self.writeString("(")
            + self.writeArray(addresses, separator: "", parenthesis: false) { (aog, self) -> Int in
                self.writeEmailAddressOrGroup(aog)
            } + self.writeString(")")
    }

    @discardableResult mutating func writeOptionalMessageID(_ id: MessageID?) -> Int {
        if let id = id {
            return self.writeMessageID(id)
        }
        return self.writeNil()
    }

    @discardableResult mutating func writeEnvelope(_ envelope: Envelope) -> Int {
        self.writeString("(") + self.writeNString(envelope.date?.value) + self.writeSpace()
            + self.writeNString(envelope.subject) + self.writeSpace() + self.writeEnvelopeAddresses(envelope.from)
            + self.writeSpace() + self.writeEnvelopeAddresses(envelope.sender) + self.writeSpace()
            + self.writeEnvelopeAddresses(envelope.reply) + self.writeSpace() + self.writeEnvelopeAddresses(envelope.to)
            + self.writeSpace() + self.writeEnvelopeAddresses(envelope.cc) + self.writeSpace()
            + self.writeEnvelopeAddresses(envelope.bcc) + self.writeSpace()
            + self.writeOptionalMessageID(envelope.inReplyTo) + self.writeSpace()
            + self.writeOptionalMessageID(envelope.messageID) + self.writeString(")")
    }
}
