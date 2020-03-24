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

extension NIOIMAP.Envelope {

    public typealias Addresses = [NIOIMAP.Address]?
    
    /// IMAPv4 `env-sender`
    public typealias Sender = Addresses
    
    /// IMAPv4 `env-to`
    public typealias To = Addresses
    
    /// IMAPv4 `env-reply-to`
    public typealias ReplyTo = Addresses
    
    /// IMAPv4 `env-bcc`
    public typealias BCC = Addresses
    
    /// IMAPv4 `env-cc`
    public typealias CC = Addresses
    
    /// IMAPv4 `env-from`
    public typealias From = Addresses
    
    /// IMAPv4 `env-in-reply-to`
    public typealias InReplyTo = NIOIMAP.NString
    
    /// IMAPv4 `env-date`
    public typealias Date = String?
    
    /// IMAPv4 `env-message-id`
    public typealias MessageID = NIOIMAP.NString
    
    /// IMAPv4 `env-subject`
    public typealias Subject = NIOIMAP.NString
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeEnvelopeAddresses(_ addresses: NIOIMAP.Envelope.Addresses) -> Int {
        guard let addresses = addresses else {
            return self.writeNil()
        }

        return
            self.writeString("(") +
            self.writeArray(addresses, separator: "", parenthesis: false) { (address, self) -> Int in
                self.writeAddress(address)
            } +
            self.writeString(")")
    }

    @discardableResult mutating func writeEnvelopeDate(_ date: NIOIMAP.Envelope.Date) -> Int {
        self.writeOptionalString(date)
    }
    
    @discardableResult mutating func writeOptionalString(_ string: String?) -> Int {
        if let string = string {
            return self.writeString("\"\(string)\"")
        } else {
            return self.writeNil()
        }
    }
    
}
