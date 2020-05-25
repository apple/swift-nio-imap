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

/// Unique Message Identifier
///
/// See RFC 3501 section 2.3.1.1.
public struct UID: RawRepresentable, Equatable {
    public var rawValue: Int
    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = rawValue
    }

    public static let min = UID(1)
    public static let max = UID(UInt32.max)
}

// MARK: - Integer literal

extension UID: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(rawValue: value)!
    }

    public init(_ value: Int) {
        self.init(rawValue: value)!
    }

    public init(_ value: UInt32) {
        self.rawValue = Int(value)
    }
}

// MARK: - Comparable

extension UID: Strideable {
    public static func < (lhs: UID, rhs: UID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func <= (lhs: UID, rhs: UID) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }

    public func distance(to other: UID) -> Int {
        other.rawValue - self.rawValue
    }

    public func advanced(by n: Int) -> UID {
        UID(rawValue: self.rawValue + n)!
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUID(_ num: UID) -> Int {
        self.writeString("\(num.rawValue)")
    }

    @discardableResult mutating func writeUIDOrWildcard(_ num: UID) -> Int {
        if num == .max {
            return self.writeString("*")
        } else {
            return self.writeString("\(num.rawValue)")
        }
    }
}

// MARK: - Swift Ranges

extension UID {
    public static prefix func ... (value: Self) -> UIDRange {
        UIDRange(left: .min, right: value)
    }

    public static postfix func ... (value: Self) -> UIDRange {
        UIDRange(left: value, right: .max)
    }

    public static func ... (lower: Self, upper: Self) -> UIDRange {
        UIDRange(left: lower, right: upper)
    }
}
