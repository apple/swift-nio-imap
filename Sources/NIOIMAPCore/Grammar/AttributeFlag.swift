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
public struct AttributeFlag: Hashable, Sendable {
    /// The raw `String` to use as the flag.
    internal let stringValue: String

    // yep, we need 4, because the spec requires 2 literal \\ characters
    /// "\\Answered"
    public static let answered = Self("\\\\Answered")

    /// "\\Flagged"
    public static let flagged = Self("\\\\Flagged")

    /// "\\Deleted"
    public static let deleted = Self("\\\\Deleted")

    /// "\\Seen"
    public static let seen = Self("\\\\Seen")

    /// "\\Draft"
    public static let draft = Self("\\\\Draft")

    /// Creates a new `AttributeFlag` from the give raw `String`.
    /// - parameter rawValue: The raw `String` to use as the flag. Will be lower-cased.
    public init(_ stringValue: String) {
        self.stringValue = stringValue.lowercased()
    }
}

extension String {
    public init(_ other: AttributeFlag) {
        self = other.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAttributeFlag(_ flag: AttributeFlag) -> Int {
        self.writeString(flag.stringValue)
    }
}
