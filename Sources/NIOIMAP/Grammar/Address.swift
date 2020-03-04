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

    /// IMAPv4 `address`
    public struct Address: Equatable {
        
        /// IMAPv4 `addr-name`
        public typealias Name = NString
        
        /// IMAPv4 `addr-adl`
        public typealias Adl = NString
        
        /// IMAPv4 `addr-host`
        public typealias Host = NString
        
        /// IMAPv4 `addr-mailbox`
        public typealias Mailbox = NString
        
        public var name: Name
        public var adl: Adl
        public var mailbox: Mailbox
        public var host: Host

        /// Convenience function for a better experience when chaining multiple types.
        public static func name(_ name: Name, adl: Adl, mailbox: Mailbox, host: Host) -> Self {
            return Self(name: name, adl: adl, mailbox: mailbox, host: host)
        }
    }
    
}

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeAddress(_ address: NIOIMAP.Address) -> Int {
        self.writeString("(") +
        self.writeNString(address.name) +
        self.writeSpace() +
        self.writeNString(address.adl) +
        self.writeSpace() +
        self.writeNString(address.mailbox) +
        self.writeSpace() +
        self.writeNString(address.host) +
        self.writeString(")")
    }
    
}
