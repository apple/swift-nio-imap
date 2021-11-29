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

/// Message Sequence Number
///
/// See RFC 3501 section 2.3.1.2.
///
/// IMAPv4 `seq-number`
public struct SequenceNumber: MessageIdentifier {
    /// The raw value of the sequence number, defined in RFC 3501 to be an unsigned 32-bit integer.
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceNumber(_ num: SequenceNumber) -> Int {
        self.writeString("\(num.rawValue)")
    }

    @discardableResult mutating func writeSequenceNumberOrWildcard(_ num: SequenceNumber) -> Int {
        if num.rawValue == UInt32.max {
            return self.writeString("*")
        } else {
            return self.writeString("\(num.rawValue)")
        }
    }
}

// MARK: - Swift Ranges

extension SequenceNumber {
    /// Creates a new `SequenceRange` from `.min` to `value`.
    /// - parameter value: The upper bound.
    /// - returns: A new `SequenceRange`.
    public static prefix func ... (value: Self) -> SequenceRange {
        SequenceRange((.min) ... value)
    }

    /// Creates a new `SequenceRange` from `value` to `.max`.
    /// - parameter value: The lower bound.
    /// - returns: A new `SequenceRange`.
    public static postfix func ... (value: Self) -> SequenceRange {
        SequenceRange(value ... (.max))
    }

    /// Creates a `SequenceRange` from lower and upper bounds.
    /// - parameter lower: The lower bound.
    /// - parameter upper: The upper bound.
    /// - returns: A new `SequenceRange`.
    public static func ... (lower: Self, upper: Self) -> SequenceRange {
        SequenceRange(lower ... upper)
    }
}
