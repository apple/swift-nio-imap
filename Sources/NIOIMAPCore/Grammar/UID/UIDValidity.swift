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

/// A unique identifier validity value that ensures persistent message identification across sessions.
///
/// A `UIDValidity` is a 32-bit unsigned integer that, when combined with a ``UID``, forms a
/// 64-bit value guaranteeing that the pair identifies the same message forever, even across
/// mailbox deletions and recreations.
///
/// The server sends a `UIDVALIDITY` response code when a client selects a mailbox. If UIDs
/// from a previous session fail to persist, the server MUST return a new (higher) `UIDValidity`
/// value, allowing clients to detect when UIDs have been invalidated.
///
/// A `UIDValidity` must be greater than zero.
///
/// See [RFC 3501 Section 2.3.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.1)
/// for details on unique identifier validity.
///
/// ## Related types
///
/// Combine with ``UID`` to create persistent message identifiers: a (UID, UIDValidity) pair
/// uniquely identifies a message across all sessions and mailbox reincarnations.
public struct UIDValidity: Hashable, Sendable {
    /// The underlying raw value.
    @usableFromInline
    let rawValue: UInt32

    /// Creates a `UIDValidity` from some `BinaryInteger` after checking
    /// that the given value fits within a `UInt32`.
    /// - parameter source: Some `BinaryInteger`.
    /// - returns: `nil` if the given value cannot fit within a `UInt32`, otherwise a new `UIDValidity`.
    @inlinable
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source > 0, let rawValue = UInt32(exactly: source) else { return nil }
        self.rawValue = rawValue
    }
}

// MARK: - Integer literal

extension UIDValidity: ExpressibleByIntegerLiteral {
    /// Creates a `UIDValidity` from some integer literal value.
    /// - parameter value: The literal value.
    public init(integerLiteral value: UInt32) {
        self.init(exactly: value)!
    }
}

// MARK: - Binary Integer

extension BinaryInteger {
    public init(_ value: UIDValidity) {
        self = Self(value.rawValue)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDValidity(_ data: UIDValidity) -> Int {
        self.writeString("\(data.rawValue)")
    }
}
