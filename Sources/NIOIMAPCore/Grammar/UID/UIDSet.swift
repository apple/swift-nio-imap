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

/// A set contains an array of `UIDRange` to represent a (potentially large) collection of messages.
public struct UIDSet: Hashable {
    
    /// `true` if `ranges` contains no `UIDRange`s.
    public var isEmpty: Bool {
        return self.ranges.isEmpty
    }
    
    /// A non-empty array of UID ranges.
    public var ranges: [UIDRange]

    /// Creates a new `UIDset`.
    /// - parameter ranges: A non-empty array of ranges.
    /// - returns: `nil` if `ranges` is empty, otherwise a new `UIDSet`.
    public init?(_ ranges: [UIDRange]) {
        guard !ranges.isEmpty else { return nil }
        self.ranges = ranges
    }
}

extension UIDSet {
    /// Creates a `UIDSet` from a closed range.
    /// - parameter range: The closed range to use.
    public init(_ range: ClosedRange<UID>) {
        self.init(UIDRange(range))
    }

    /// Creates a `UIDSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeThrough<UID>) {
        self.init(UIDRange(range))
    }

    /// Creates a `UIDSet` from a partial range.
    /// - parameter range: The partial range to use.
    public init(_ range: PartialRangeFrom<UID>) {
        self.init(UIDRange(range))
    }

    /// Creates a set from a single range.
    /// - parameter range: The `UIDRange` to construct a set from.
    public init(_ range: UIDRange) {
        self.ranges = [range]
    }
}

// MARK: - CustomStringConvertible

extension UIDSet: CustomStringConvertible {
    /// Creates a human-readable text representation of the set by joined ranges with a comma.
    public var description: String {
        ranges.map { "\($0)" }.joined(separator: ",")
    }
}

// MARK: - Array Literal

extension UIDSet: ExpressibleByArrayLiteral {
    /// Creates a new UIDSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: UIDRange...) {
        self.init(elements)!
    }
}

extension UIDSet {
    /// A set that contains a single range, that in turn contains all messages.
    public static let all = UIDSet(UIDRange.all)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDSet(_ set: UIDSet) -> Int {
        self.writeArray(set.ranges, separator: ",", parenthesis: false) { (element, self) in
            self.writeUIDRange(element)
        }
    }
}
