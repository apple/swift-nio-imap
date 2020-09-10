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

/// RFC 7162 Condstore
public struct AttributeFlag: Equatable, RawRepresentable {
    
    public var rawValue: String
    
    /// "\\Answered"
    public static var answered = Self(rawValue: "\\\\Answered") // yep, we need 4, because the spec requires 2 literal \\ characters
    
    /// "\\Flagged"
    public static var flagged = Self(rawValue: "\\\\Flagged")
    
    /// "\\Deleted"
    public static var deleted = Self(rawValue: "\\\\Deleted")
    
    /// "\\Seen"
    public static var seen = Self(rawValue: "\\\\Seen")
    
    /// "\\Draft"
    public static var draft = Self(rawValue: "\\\\Draft")
    
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - Encoding
extension EncodeBuffer {
    
    @discardableResult mutating func writeAttributeFlag(_ flag: AttributeFlag) -> Int {
        self.writeString(flag.rawValue)
    }
    
}
