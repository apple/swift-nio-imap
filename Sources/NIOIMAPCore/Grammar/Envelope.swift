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

extension NIOIMAP {
    /// IMAPv4 `envelope`
    public struct Envelope: Equatable {
        public var date: NString
        public var subject: NString
        public var from: [NIOIMAP.Address]
        public var sender: [NIOIMAP.Address]
        public var reply: [NIOIMAP.Address]
        public var to: [NIOIMAP.Address]
        public var cc: [NIOIMAP.Address]
        public var bcc: [NIOIMAP.Address]
        public var inReplyTo: NString
        public var messageID: NString

        public static func date(_ date: NString, subject: NIOIMAP.NString, from: [NIOIMAP.Address], sender: [NIOIMAP.Address], reply: [NIOIMAP.Address], to: [NIOIMAP.Address], cc: [NIOIMAP.Address], bcc: [NIOIMAP.Address], inReplyTo: NIOIMAP.NString, messageID: NIOIMAP.NString) -> Self {
            Self(date: date, subject: subject, from: from, sender: sender, reply: reply, to: to, cc: cc, bcc: bcc, inReplyTo: inReplyTo, messageID: messageID)
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeEnvelopeAddresses(_ addresses: [NIOIMAP.Address]) -> Int {
        guard addresses.count > 0 else {
            return self.writeNil()
        }

        return
            self.writeString("(") +
            self.writeArray(addresses, separator: "", parenthesis: false) { (address, self) -> Int in
                self.writeAddress(address)
            } +
            self.writeString(")")
    }

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
