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

    typealias Addresses = [NIOIMAP.Address]?
    
    /// IMAPv4 `env-sender`
    typealias Sender = Addresses
    
    /// IMAPv4 `env-to`
    typealias To = Addresses
    
    /// IMAPv4 `env-reply-to`
    typealias ReplyTo = Addresses
    
    /// IMAPv4 `env-bcc`
    typealias BCC = Addresses
    
    /// IMAPv4 `env-cc`
    typealias CC = Addresses
    
    /// IMAPv4 `env-from`
    typealias From = Addresses
    
    /// IMAPv4 `env-in-reply-to`
    typealias InReplyTo = NIOIMAP.NString
    
    /// IMAPv4 `env-date`
    typealias Date = NIOIMAP.NString
    
    /// IMAPv4 `env-message-id`
    typealias MessageID = NIOIMAP.NString
    
    /// IMAPv4 `env-subject`
    typealias Subject = NIOIMAP.NString
    
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

}
