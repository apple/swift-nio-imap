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

/// A wrapper around a `MessageIdentifierSet` that enforces at least one element.
public struct MessageIdentifierSetNonEmpty<IdentifierType: MessageIdentifier>: Hashable {
    /// A set that contains a single range, that in turn contains all messages.
    public static var all: Self {
        MessageIdentifierSetNonEmpty(set: .all)!
    }

    /// The underlying `MessageIdentifierSet`
    public private(set) var set: MessageIdentifierSet<IdentifierType>

    /// Creates a new `MessageIdentifierSetNonEmpty` from a `MessageIdentifierSet`, after first
    /// validating that the set is not emtpy.
    /// - parameter set: The underlying `MessageIdentifierSet` to use.
    /// - returns: `nil` if the given `MessageIdentifierSet` is empty.
    public init?(set: MessageIdentifierSet<IdentifierType>) {
        guard set.count > 0 else {
            return nil
        }
        self.set = set
    }

    /// Creates a new `MessageIdentifierSetNonEmpty` from a `MessageIdentifierRange`.
    public init(range: MessageIdentifierRange<IdentifierType>) {
        self.set = MessageIdentifierSet(range)
    }
}

// MARK: - CustomDebugStringConvertible

extension MessageIdentifierSetNonEmpty: CustomDebugStringConvertible {
    /// Creates a human-readable text representation of the set by joined ranges with a comma.
    public var debugDescription: String {
        self.set.debugDescription
    }
}

// MARK: - Array Literal

extension MessageIdentifierSetNonEmpty: ExpressibleByArrayLiteral {
    /// Creates a new MessageIdentifierSet from a literal array of ranges.
    /// - parameter arrayLiteral: The elements to use, assumed to be non-empty.
    public init(arrayLiteral elements: MessageIdentifierRange<IdentifierType>...) {
        precondition(elements.count > 0, "At least one element is required.")
        self.set = MessageIdentifierSet(elements)
    }
}

// MARK: - Unknown


extension MessageIdentifierSetNonEmpty<UnknownMessageIdentifier> {
    init<A: MessageIdentifier>(_ other: MessageIdentifierSetNonEmpty<A>) {
        self.init(set: MessageIdentifierSet<IdentifierType>(other.set))!
    }
}

extension MessageIdentifierSetNonEmpty {
    init(unknown other: MessageIdentifierSetNonEmpty<UnknownMessageIdentifier>) {
        self.init(set: MessageIdentifierSet<IdentifierType>(unknown: other.set))!
    }
}

// MARK: - Min Max

extension MessageIdentifierSetNonEmpty {
    /// Returns the minimum element in the set.
    ///
    /// - Complexity: O(1)
    @warn_unqualified_access
    @inlinable
    public func min() -> IdentifierType {
        set.min()!
    }

    /// Returns the maximum element in the set.
    ///
    /// - Complexity: O(1)
    @warn_unqualified_access
    @inlinable
    public func max() -> IdentifierType {
        set.max()!
    }
}

// MARK: - Encoding

extension MessageIdentifierSetNonEmpty {
    @_spi(NIOIMAPInternal) public func writeIntoBuffer(_ buffer: inout EncodeBuffer) -> Int {
        self.set.writeIntoBuffer(&buffer)
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeUIDSet<IdentifierType: MessageIdentifier>(_ set: MessageIdentifierSetNonEmpty<IdentifierType>) -> Int {
        set.writeIntoBuffer(&self)
    }
}
