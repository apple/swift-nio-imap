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

extension LastCommandSet where T == SequenceRangeSet {
    /// Creates a `SequenceSet` from a non-empty array of `SequenceRange`.
    /// - parameter ranges: An array of `SequenceRange` to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a new `SequenceSet`.
    public init?(_ ranges: [SequenceRange]) {
        if let rangeSet = SequenceRangeSet(ranges) {
            self = .set(rangeSet)
        } else {
            return nil
        }
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use.
    public init(_ range: ClosedRange<SequenceNumber>) {
        self = .set(SequenceRangeSet(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use from `.min`.
    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self = .set(SequenceRangeSet(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use, up to `.max`.
    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self = .set(SequenceRangeSet(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use.
    public init(_ range: SequenceRange) {
        self = .set(SequenceRangeSet(range))
    }
}

extension LastCommandSet: ExpressibleByArrayLiteral where T == SequenceRangeSet {
    /// Creates a `SequenceSet` from an array of `SequenceRange`. The array is assumed
    /// to be non-empty, however the initialiser will crash if this is not the case.
    /// - parameter ranges: An array of `SequenceRange` to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a new `SequenceSet`.
    public init(arrayLiteral elements: SequenceRange...) {
        self = .set(SequenceRangeSet(elements)!)
    }
}

extension LastCommandSet where T == SequenceRangeSet {
    /// A `SequenceSet` that contains a single `SequenceRangeSet`, that in turn covers every possible `SequenceNumber`.
    public static let all: Self = .set(SequenceRangeSet.all)
}
