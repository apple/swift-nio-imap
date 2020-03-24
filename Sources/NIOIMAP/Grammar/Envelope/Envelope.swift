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

import NIO

extension NIOIMAP {
    
    /// IMAPv4 `envelope`
    public struct Envelope: Equatable {
        public var date: Date
        public var subject: Subject
        public var from: From
        public var sender: Sender
        public var reply: ReplyTo
        public var to: To
        public var cc: CC
        public var bcc: BCC
        public var inReplyTo: InReplyTo
        public var messageID: MessageID
        
        public static func date(_ date: NIOIMAP.Envelope.Date, subject: NIOIMAP.Envelope.Subject, from: NIOIMAP.Envelope.From, sender: NIOIMAP.Envelope.Sender, reply: NIOIMAP.Envelope.ReplyTo, to: NIOIMAP.Envelope.To, cc: NIOIMAP.Envelope.CC, bcc: NIOIMAP.Envelope.BCC, inReplyTo: NIOIMAP.Envelope.InReplyTo, messageID: NIOIMAP.Envelope.MessageID) -> Self {
            return Self(date: date, subject: subject, from: from, sender: sender, reply: reply, to: to, cc: cc, bcc: bcc, inReplyTo: inReplyTo, messageID: messageID)
        }
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeEnvelope(_ envelope: NIOIMAP.Envelope) -> Int {
        self.writeString("(") +
        self.writeEnvelopeDate(envelope.date) +
        self.writeSpace() +
        self.writeEnvelopeSubject(envelope.subject) +
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
        self.writeEnvelopeInReplyTo(envelope.inReplyTo) +
        self.writeSpace() +
        self.writeEnvelopeMessageID(envelope.messageID) +
        self.writeString(")")
    }

}
