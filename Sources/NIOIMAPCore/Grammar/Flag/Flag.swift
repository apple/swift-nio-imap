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

/// IMAP Flag
///
/// Flags are case preserving, but case insensitive.
/// As such e.g. `.extension("\\FOOBAR") == .extension("\\FooBar")`, but
/// it will round-trip preserving its case.
public struct Flag: RawRepresentable, Hashable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func == (lhs: Flag, rhs: Flag) -> Bool {
        lhs.rawValue.uppercased() == rhs.rawValue.uppercased()
    }

    public func hash(into hasher: inout Hasher) {
        rawValue.uppercased().hash(into: &hasher)
    }

    public var hashValue: Int {
        var hasher = Hasher()
        hash(into: &hasher)
        return hasher.finalize()
    }
}

extension Flag {
    public static let answered = Self(rawValue: "\\Answered")
    public static let flagged = Self(rawValue: "\\Flagged")
    public static let deleted = Self(rawValue: "\\Deleted")
    public static let seen = Self(rawValue: "\\Seen")
    public static let draft = Self(rawValue: "\\Draft")

    public static func keyword(_ keyword: Keyword) -> Self {
        self.init(rawValue: keyword.rawValue)
    }

    /// Creates a new `Flag` that complies to RFC 3501 `flag-extension`
    /// Note: If the provided extension is invalid then we will crash
    /// - parameter string: The new flag text, *must* begin with a single '\'
    /// - returns: A newly-create `Flag`
    public static func `extension`(_ string: String) -> Self {
        precondition(string.first == "\\", "Flag extensions must begin with \\")
        return Self(rawValue: string)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFlags(_ flags: [Flag]) -> Int {
        self.writeArray(flags) { (flag, self) -> Int in
            self.writeFlag(flag)
        }
    }

    @discardableResult mutating func writeFlag(_ flag: Flag) -> Int {
        writeString(flag.rawValue)
    }
}
