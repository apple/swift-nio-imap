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
        public var from: Addresses
        public var sender: Addresses
        public var reply: Addresses
        public var to: Addresses
        public var cc: Addresses
        public var bcc: Addresses
        public var inReplyTo: InReplyTo
        public var messageID: MessageID
        
        public static func date(_ date: NIOIMAP.Envelope.Date, subject: NIOIMAP.Envelope.Subject, from: NIOIMAP.Envelope.Addresses, sender: NIOIMAP.Envelope.Addresses, reply: NIOIMAP.Envelope.Addresses, to: NIOIMAP.Envelope.Addresses, cc: NIOIMAP.Envelope.Addresses, bcc: NIOIMAP.Envelope.Addresses, inReplyTo: NIOIMAP.Envelope.InReplyTo, messageID: NIOIMAP.Envelope.MessageID) -> Self {
            return Self(date: date, subject: subject, from: from, sender: sender, reply: reply, to: to, cc: cc, bcc: bcc, inReplyTo: inReplyTo, messageID: messageID)
        }
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeEnvelope(_ envelope: NIOIMAP.Envelope) -> Int {
        self.writeString("(") +
        self.writeNString(envelope.date) +
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
        self.writeNString(envelope.inReplyTo) +
        self.writeSpace() +
        self.writeNString(envelope.messageID) +
        self.writeString(")")
    }

}
