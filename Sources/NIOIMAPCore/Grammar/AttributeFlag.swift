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

/// Used when performing a search with `MODSEQ`. Note that this is similar to `Flag`, however `.recent`
/// is not present.
public struct AttributeFlag: Hashable, RawRepresentable {
    
    /// The raw `String` to use as the flag.
    public var rawValue: String

    // yep, we need 4, because the spec requires 2 literal \\ characters
    /// "\\Answered"
    public static var answered = Self(rawValue: "\\\\Answered")

    /// "\\Flagged"
    public static var flagged = Self(rawValue: "\\\\Flagged")

    /// "\\Deleted"
    public static var deleted = Self(rawValue: "\\\\Deleted")

    /// "\\Seen"
    public static var seen = Self(rawValue: "\\\\Seen")

    /// "\\Draft"
    public static var draft = Self(rawValue: "\\\\Draft")

    /// Creates a new `AttributeFlag` from the give raw `String`.
    /// - parameter rawValue: The raw `String` to use as the flag.
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
