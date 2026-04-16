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

/// A non-empty wrapper around ``MessageIdentifierSet`` guaranteeing at least one message identifier.
///
/// Many IMAP commands require a non-empty message set (e.g., `FETCH 1:5`, `STORE`, `COPY`,
/// `EXPUNGE`). `MessageIdentifierSetNonEmpty` wraps a ``MessageIdentifierSet`` with a type-level
/// guarantee that it contains at least one element.
///
/// Use the initializer ``init(set:)`` to validate that a set is non-empty, or construct
/// directly from a range using ``init(range:)``.
///
/// ## Examples
///
/// ```swift
/// // Create from a range (guaranteed non-empty)
/// let set = MessageIdentifierSetNonEmpty(range: 5...10)
///
/// // Try to create from an existing set
/// if let nonEmpty = MessageIdentifierSetNonEmpty(set: someSet) {
///     // someSet is non-empty
/// }
///
/// // Access the underlying set
/// let all = MessageIdentifierSetNonEmpty.all
/// let min = all.min()  // Returns 1
/// let max = all.max()  // Returns UInt32.max
/// ```
///
/// ## Related Types
///
/// - ``MessageIdentifierSet`` is the wrapped type (may be empty).
/// - ``MessageIdentifierRange`` represents a single contiguous range.
/// - ``UIDSetNonEmpty`` is a type alias for `MessageIdentifierSetNonEmpty<UID>`.
public struct MessageIdentifierSetNonEmpty<IdentifierType: MessageIdentifier>: Hashable, Sendable {
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
    /// Creates a new MessageIdentifierSetNonEmpty from a literal array of ranges.
    /// - parameter elements: The message identifier ranges to include in the non-empty set.
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
    @discardableResult mutating func writeUIDSet<IdentifierType: MessageIdentifier>(
        _ set: MessageIdentifierSetNonEmpty<IdentifierType>
    ) -> Int {
        set.writeIntoBuffer(&self)
    }
}
