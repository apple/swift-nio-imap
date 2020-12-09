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

/// Represents a `SequenceRangeSet` using either a literal value, or some
/// value stored on the server.
public enum SequenceSet: Hashable {
    
    /// A literal `SequenceRangeSet` to use.
    case range(SequenceRangeSet)
    
    /// References result of the last command stored on the server.
    case lastCommand
}

extension SequenceSet {
    
    /// Creates a `SequenceSet` from a non-empty array of `SequenceRange`.
    /// - parameter ranges: An array of `SequenceRange` to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a new `SequenceSet`.
    public init?(_ ranges: [SequenceRange]) {
        if let rangeSet = SequenceRangeSet(ranges) {
            self = .range(rangeSet)
        } else {
            return nil
        }
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use.
    public init(_ range: ClosedRange<SequenceNumber>) {
        self = .range(SequenceRangeSet(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use from `.min`.
    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self = .range(SequenceRangeSet(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use, up to `.max`.
    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self = .range(SequenceRangeSet(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use.
    public init(_ range: SequenceRange) {
        self = .range(SequenceRangeSet(range))
    }
}

extension SequenceSet: ExpressibleByArrayLiteral {
    
    /// Creates a `SequenceSet` from an array of `SequenceRange`. The array is assumed
    /// to be non-empty, however the initialiser will crash if this is not the case.
    /// - parameter ranges: An array of `SequenceRange` to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a new `SequenceSet`.
    public init(arrayLiteral elements: SequenceRange...) {
        self = .range(SequenceRangeSet(elements)!)
    }
}

extension SequenceSet {
    
    /// A `SequenceSet` that contains a single `SequenceRangeSet`, that in turn covers every possible `SequenceNumber`.
    public static let all: SequenceSet = .range(SequenceRangeSet.all)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceSet(_ set: SequenceSet) -> Int {
        switch set {
        case .range(let sequenceRangeSet):
            return self.writeSequenceRangeSet(sequenceRangeSet)
        case .lastCommand:
            return self.writeString("$")
        }
    }
}
