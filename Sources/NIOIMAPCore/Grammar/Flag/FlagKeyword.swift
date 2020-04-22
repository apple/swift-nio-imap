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
        
        public static func other(_ string: String) -> Self? {
            return Self(string)
        }
        
        public var rawValue: String
        
        public init?(_ string: String) {
            let valid = string.utf8.allSatisfy { c -> Bool in
                return c.isAtomChar
            }
            guard valid else {
                return nil
            }
            self.rawValue = string.uppercased()
        }
        
        fileprivate init(alreadyUppercased string: String) {
            precondition(string.utf8.allSatisfy { (c) -> Bool in
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
    public static let forwarded = Self(alreadyUppercased: "$FORWARDED")
    
    /// `$Junk`
    public static let junk = Self(alreadyUppercased: "$JUNK")
    
    /// `$NotJunk`
    public static let notJunk = Self(alreadyUppercased: "$NOTJUNK")
    
    /// `Redirected`
    public static let unregistered_redirected = Self(alreadyUppercased: "REDIRECTED")
    
    /// `Forwarded`
    public static let unregistered_forwarded = Self(alreadyUppercased: "FORWARDED")
    
    /// `Junk`
    public static let unregistered_junk = Self(alreadyUppercased: "JUNK")
    
    /// `NotJunk`
    public static let unregistered_notJunk = Self(alreadyUppercased: "NOTJUNK")
    
    /// `$MailFlagBit0`
    public static let colorBit0 = Self(alreadyUppercased: "$MAILFLAGBIT0")
    
    /// `$MailFlagBit1`
    public static let colorBit1 = Self(alreadyUppercased: "$MAILFLAGBIT1")
    
    /// `$MailFlagBit2`
    public static let colorBit2 = Self(alreadyUppercased: "$MAILFLAGBIT2")
    
    /// `$MDNSent`
    public static let mdnSent = Self(alreadyUppercased: "$MDNSENT")
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeFlagKeyword(_ keyword: NIOIMAP.Flag.Keyword) -> Int {
        self.writeString(keyword.rawValue)
    }

}
