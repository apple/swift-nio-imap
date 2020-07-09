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

enum _Flag: Hashable {
    case answered
    case flagged
    case deleted
    case seen
    case draft
    case keyword(Flag.Keyword)
    case `extension`(String)

    public static func == (lhs: _Flag, rhs: _Flag) -> Bool {
        switch (lhs, rhs) {
        case (.answered, .answered): return true
        case (.flagged, .flagged): return true
        case (.deleted, .deleted): return true
        case (.seen, .seen): return true
        case (.draft, .draft): return true
        case (.keyword(let a), .keyword(let b)): return a == b
        case (.extension(let a), .extension(let b)): return a.uppercased() == b.uppercased()
        default: return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .answered: 1.hash(into: &hasher)
        case .flagged: 2.hash(into: &hasher)
        case .deleted: 3.hash(into: &hasher)
        case .seen: 4.hash(into: &hasher)
        case .draft: 5.hash(into: &hasher)
        case .keyword(let k):
            6.hash(into: &hasher)
            k.hash(into: &hasher)
        case .extension(let e):
            7.hash(into: &hasher)
            e.uppercased().hash(into: &hasher)
        }
    }
}

/// IMAP Flag
///
/// Flags are case preserving, but case insensitive.
/// As such e.g. `.extension("\\FOOBAR") == .extension("\\FooBar")`, but
/// it will round-trip preserving its case.
public struct Flag: Hashable {
    var _backing: _Flag

    public static var answered: Self {
        Self(_backing: .answered)
    }

    public static var flagged: Self {
        Self(_backing: .flagged)
    }

    public static var deleted: Self {
        Self(_backing: .deleted)
    }

    public static var seen: Self {
        Self(_backing: .seen)
    }

    public static var draft: Self {
        Self(_backing: .draft)
    }

    public static func keyword(_ keyword: Keyword) -> Self {
        Self(_backing: .keyword(keyword))
    }

    /// Creates a new `Flag` that complies to RFC 3501 `flag-extension`
    /// Note: If the provided extension is invalid then we will crash
    /// - parameter string: The new flag text, *must* begin with a single '\'
    /// - returns: A newly-create `Flag`
    public static func `extension`(_ string: String) -> Self {
        precondition(string.first == "\\", "Flag extensions must begin with \\")
        switch string.uppercased() {
        case "\\ANSWERED":
            return .answered
        case "\\FLAGGED":
            return .flagged
        case "\\DELETED":
            return .deleted
        case "\\SEEN":
            return .seen
        case "\\DRAFT":
            return .draft
        default:
            return Self(_backing: .extension(string))
        }
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
        switch flag._backing {
        case .answered:
            return self.writeString("\\Answered")
        case .flagged:
            return self.writeString("\\Flagged")
        case .deleted:
            return self.writeString("\\Deleted")
        case .seen:
            return self.writeString("\\Seen")
        case .draft:
            return self.writeString("\\Draft")
        case .keyword(let keyword):
            return self.writeFlagKeyword(keyword)
        case .extension(let x):
            return self.writeString(x)
        }
    }
}
