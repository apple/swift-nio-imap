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

/// The envelope of a message contains various fields, all of which may be empty or `nil`.
/// It's entirely possible for an envelope to be completely empty, though this will be rare.
public struct Envelope: Hashable {
    /// The local time and date that the message was written.
    public var date: InternetMessageDate?

    /// The subject of the message.
    public var subject: ByteBuffer?

    /// The email address, and optionally the name of the author(s).
    public var from: [EmailAddressListElement]

    /// Address of the actual sender acting on behalf of the author.
    public var sender: [EmailAddressListElement]

    /// Who a reply should be sent to.
    public var reply: [EmailAddressListElement]

    /// Who the message was sent to
    public var to: [EmailAddressListElement]

    /// The carbon-copy list.
    public var cc: [EmailAddressListElement]

    /// The blind-carbon-copy list
    public var bcc: [EmailAddressListElement]

    /// The message ID that this message replied to.
    public var inReplyTo: MessageID?

    /// A unique identifier for the message.
    public var messageID: MessageID?

    /// Creates a new envelope.
    /// - parameter date: The local time and date that the message was written.
    /// - parameter subject: The subject of the message.
    /// - parameter from: The email address, and optionally the name of the author(s).
    /// - parameter sender: Address of the actual sender acting on behalf of the author.
    /// - parameter reply: Who a reply should be sent to.
    /// - parameter to: Who the message was sent to
    /// - parameter cc: The carbon-copy list.
    /// - parameter bcc: The blind-carbon-copy list
    /// - parameter inReplyTo: The message ID that this message replied to.
    /// - parameter messageID: A unique identifier for the message.
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
            self.writeString("(") +
            self.writeArray(addresses, separator: "", parenthesis: false) { (aog, self) -> Int in
                self.writeEmailAddressOrGroup(aog)
            } +
            self.writeString(")")
    }

    @discardableResult mutating func writeOptionalMessageID(_ id: MessageID?) -> Int {
        if let id = id {
            return self.writeMessageID(id)
        }
        return self.writeNil()
    }

    @discardableResult mutating func writeEnvelope(_ envelope: Envelope) -> Int {
        self.writeString("(") +
            self.writeNString(envelope.date?.value) +
            self.writeSpace() +
            self.writeNString(envelope.subject) +
            self.writeSpace() +
            self.writeEnvelopeAddresses(envelope.from) +
            self.writeSpace() +
            self.writeEnvelopeAddresses(envelope.sender) +
            self.writeSpace() +
            self.writeEnvelopeAddresses(envelope.reply) +
            self.writeSpace() +
            self.writeEnvelopeAddresses(envelope.to) +
            self.writeSpace() +
            self.writeEnvelopeAddresses(envelope.cc) +
            self.writeSpace() +
            self.writeEnvelopeAddresses(envelope.bcc) +
            self.writeSpace() +
            self.writeOptionalMessageID(envelope.inReplyTo) +
            self.writeSpace() +
            self.writeOptionalMessageID(envelope.messageID) +
            self.writeString(")")
    }
}
