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

extension NIOIMAP.Flag {

    /// IMAPv4 `flag-keyword`
    public struct Keyword: Equatable {
        
        public var rawValue: String
        
        public init(_ string: String) {
            precondition(string.utf8.allSatisfy { (c) -> Bool in
                return c.isAtomChar
            }, "String contains invalid characters")
            self.rawValue = string.uppercased()
        }
        
        fileprivate init(unchecked string: String) {
            assert(string.utf8.allSatisfy { (c) -> Bool in
                if c.isAlpha {
                    return c >= UInt8(ascii: "A") && c <= UInt8(ascii: "Z")
                }
                return c.isAtomChar
            })
            self.rawValue = string
        }
        
    }

}

// MARK: - Convenience
extension NIOIMAP.Flag.Keyword {
    
    /// `$Forwarded`
    public static let forwarded = Self(unchecked: "$FORWARDED")
    
    /// `$Junk`
    public static let junk = Self(unchecked: "$JUNK")
    
    /// `$NotJunk`
    public static let notJunk = Self(unchecked: "$NOTJUNK")
    
    /// `Redirected`
    public static let unregistered_redirected = Self(unchecked: "REDIRECTED")
    
    /// `Forwarded`
    public static let unregistered_forwarded = Self(unchecked: "FORWARDED")
    
    /// `Junk`
    public static let unregistered_junk = Self(unchecked: "JUNK")
    
    /// `NotJunk`
    public static let unregistered_notJunk = Self(unchecked: "NOTJUNK")
    
    /// `$MailFlagBit0`
    public static let colorBit0 = Self(unchecked: "$MAILFLAGBIT0")
    
    /// `$MailFlagBit1`
    public static let colorBit1 = Self(unchecked: "$MAILFLAGBIT1")
    
    /// `$MailFlagBit2`
    public static let colorBit2 = Self(unchecked: "$MAILFLAGBIT2")
    
    /// `$MDNSent`
    public static let mdnSent = Self(unchecked: "$MDNSENT")
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeFlagKeyword(_ keyword: NIOIMAP.Flag.Keyword) -> Int {
        self.writeString(keyword.rawValue)
    }

}
