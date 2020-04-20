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
    public struct Keyword: Equatable, ExpressibleByStringLiteral {
    
        public typealias StringLiteralType = String
        
        public var rawValue: StringLiteralType
        
        public init(stringLiteral value: StringLiteralType) {
            self.rawValue = value
        }
        
    }

}

// MARK: - Convenience
extension NIOIMAP.Flag.Keyword {
    
    /// `$Forwarded`
    public static let forwarded = Self(stringLiteral: "$Forwarded")
    
    /// `$Junk`
    public static let junk = Self(stringLiteral: "$Junk")
    
    /// `$NotJunk`
    public static let notJunk = Self(stringLiteral: "$NotJunk")
    
    /// `Redirected`
    public static let unregistered_redirected = Self(stringLiteral: "Redirected")
    
    /// `Forwarded`
    public static let unregistered_forwarded = Self(stringLiteral: "Forwarded")
    
    /// `Junk`
    public static let unregistered_junk = Self(stringLiteral: "Junk")
    
    /// `NotJunk`
    public static let unregistered_notJunk = Self(stringLiteral: "NotJunk")
    
    /// `$MailFlagBit0`
    public static let colorBit0 = Self(stringLiteral: "$MailFlagBit0")
    
    /// `$MailFlagBit1`
    public static let colorBit1 = Self(stringLiteral: "$MailFlagBit1")
    
    /// `$MailFlagBit2`
    public static let colorBit2 = Self(stringLiteral: "$MailFlagBit2")
    
    /// `$MDNSent`
    public static let mdnSent = Self(stringLiteral: "$MDNSent")
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeFlagKeyword(_ keyword: NIOIMAP.Flag.Keyword) -> Int {
        self.writeString(keyword.rawValue)
    }

}
