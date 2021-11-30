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

extension LastCommandSet where SetType == MessageIdentifierSet<SequenceNumber> {
    /// Creates a `SequenceSet` from a non-empty array of `SequenceRange`.
    /// - parameter ranges: An array of `SequenceRange` to use.
    /// - returns: `nil` if `ranges` is empty, otherwise a new `SequenceSet`.
    public init?(_ ranges: [MessageIdentifierRange<SequenceNumber>]) {
        guard !ranges.isEmpty else {
            return nil
        }
        self = .set(.init(ranges))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use.
    public init(_ range: ClosedRange<SequenceNumber>) {
        self = .set(MessageIdentifierSet<SequenceNumber>(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use from `.min`.
    public init(_ range: PartialRangeThrough<SequenceNumber>) {
        self = .set(MessageIdentifierSet<SequenceNumber>(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use, up to `.max`.
    public init(_ range: PartialRangeFrom<SequenceNumber>) {
        self = .set(MessageIdentifierSet<SequenceNumber>(range))
    }

    /// Creates a `SequenceSet` from a single range.
    /// - parameter range: The underlying range to use.
    public init(_ range: MessageIdentifierRange<SequenceNumber>) {
        self = .set(MessageIdentifierSet<SequenceNumber>(range))
    }
}

extension LastCommandSet where SetType == MessageIdentifierSet<SequenceNumber> {
    /// A `SequenceSet` that contains a single `SequenceRangeSet`, that in turn covers every possible `SequenceNumber`.
    public static let all: Self = .set(MessageIdentifierSet<SequenceNumber>.all)
}
