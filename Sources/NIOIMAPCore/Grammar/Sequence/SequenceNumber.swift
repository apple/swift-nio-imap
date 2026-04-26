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

/// A message sequence number representing a relative position within a mailbox.
///
/// A `SequenceNumber` is a 32-bit unsigned integer representing a message's relative position
/// in the mailbox (1 to N, where N is the total number of messages). Sequence numbers are
/// ordered by ascending ``UID`` but can be reassigned during a session when messages are
/// expunged.
///
/// For example, if message 3 is deleted, messages 4-10 are renumbered to 3-9. This dynamic
/// renumbering is the key difference from UIDs, which remain constant throughout the session
/// and beyond.
///
/// For long-term caching and cross-session identification of messages, consider using ``UID``
/// with ``UIDValidity``, or ``EmailID`` (RFC 8474) for content-based identification.
///
/// See [RFC 3501 Section 2.3.1.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.2)
/// for details on message sequence numbers.
///
/// ## Related types
///
/// Use ``UID`` to reference messages by a stable, session-independent identifier.
/// Use ``MessageIdentifierSet`` or ``MessageIdentifierRange`` to represent collections of sequence numbers.
/// To convert between ``SequenceNumber`` and ``UID`` at runtime, use ``UnknownMessageIdentifier``.
/// Use ``EmailID`` for content-based message identification.
public struct SequenceNumber: MessageIdentifier, Sendable {
    /// The raw value of the sequence number, defined in RFC 3501 to be an unsigned 32-bit integer.
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

/// A contiguous range of message sequence numbers.
///
/// `SequenceRange` is a type alias for `MessageIdentifierRange<SequenceNumber>`, representing
/// a contiguous sequence of positions in a mailbox. See ``MessageIdentifierRange`` for detailed
/// documentation on range operations, construction, and wire format encoding.
///
/// See [RFC 3501 Section 2.3.1.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.2)
/// for message sequence number definitions.
public typealias SequenceRange = MessageIdentifierRange<SequenceNumber>

/// A set of message sequence numbers, possibly non-contiguous.
///
/// `SequenceSet` is a type alias for `MessageIdentifierSet<SequenceNumber>`, representing
/// a collection of sequence numbers using optimized range storage. See ``MessageIdentifierSet``
/// for detailed documentation on set operations, construction, and wire format encoding.
///
/// See [RFC 3501 Section 6](https://datatracker.ietf.org/doc/html/rfc3501#section-6)
/// for message set syntax.
public typealias SequenceSet = MessageIdentifierSet<SequenceNumber>

// MARK: - Conversion

extension SequenceNumber {
    public init(_ other: UnknownMessageIdentifier) {
        self.init(rawValue: other.rawValue)
    }
}

extension UnknownMessageIdentifier {
    public init(_ other: SequenceNumber) {
        self.init(rawValue: other.rawValue)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceNumber(_ num: SequenceNumber) -> Int {
        self.writeString("\(num.rawValue)")
    }

    @discardableResult mutating func writeSequenceNumberOrWildcard(_ num: SequenceNumber) -> Int {
        guard num.rawValue < UInt32.max else {
            return self.writeString("*")
        }
        return self.writeString("\(num.rawValue)")
    }
}
