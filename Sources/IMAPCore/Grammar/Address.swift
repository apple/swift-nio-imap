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

extension IMAPCore {

    /// IMAPv4 `address`
    public struct Address: Equatable {
        
        public var name: NString
        public var adl: NString
        public var mailbox: NString
        public var host: NString

        /// Convenience function for a better experience when chaining multiple types.
        public static func name(_ name: NString, adl: NString, mailbox: NString, host: NString) -> Self {
            return Self(name: name, adl: adl, mailbox: mailbox, host: host)
        }
    }
    
}

// MARK: - Encoding
extension ByteBufferProtocol {
    
    @discardableResult mutating func writeAddress(_ address: IMAPCore.Address) -> Int {
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
