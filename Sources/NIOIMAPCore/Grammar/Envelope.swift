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

/// IMAPv4 `envelope`
public struct Envelope: Equatable {
    public var date: NString
    public var subject: NString
    public var from: [Address]
    public var sender: [Address]
    public var reply: [Address]
    public var to: [Address]
    public var cc: [Address]
    public var bcc: [Address]
    public var inReplyTo: NString
    public var messageID: NString

    public static func date(_ date: NString, subject: NString, from: [Address], sender: [Address], reply: [Address], to: [Address], cc: [Address], bcc: [Address], inReplyTo: NString, messageID: NString) -> Self {
        Self(date: date, subject: subject, from: from, sender: sender, reply: reply, to: to, cc: cc, bcc: bcc, inReplyTo: inReplyTo, messageID: messageID)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeEnvelopeAddresses(_ addresses: [Address]) -> Int {
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

    @discardableResult mutating func writeEnvelope(_ envelope: Envelope) -> Int {
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
