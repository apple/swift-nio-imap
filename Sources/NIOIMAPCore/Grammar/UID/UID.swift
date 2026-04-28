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

/// A unique message identifier assigned to each message in a mailbox.
///
/// A `UID` is a 32-bit value that uniquely identifies a message. When combined with a
/// ``UIDValidity`` value, it forms a 64-bit identifier that must not refer to any other
/// message in the mailbox or any subsequent mailbox with the same name.
///
/// UIDs are assigned in strictly ascending fashion: each new message receives a higher UID
/// than all previously added messages. Unlike ``SequenceNumber``s, UIDs are not necessarily
/// contiguous.
///
/// Valid UIDs range from 1 to `UInt32.max` (4,294,967,295). When encoding, `UInt32.max` is
/// often rendered as `*` to represent the maximum possible value.
///
/// For long-term caching and cross-session identification of messages, consider using
/// ``EmailID`` (RFC 8474), which provides a more stable identifier that persists even when
/// messages are moved or copied between mailboxes.
///
/// See [RFC 3501 Section 2.3.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.1)
/// for details on unique identifier handling.
///
/// ## Related types
///
/// Use ``SequenceNumber`` to reference messages by their current position in the mailbox.
/// Use ``MessageIdentifierSet`` or ``MessageIdentifierRange`` to represent collections of UIDs.
/// Combine with ``UIDValidity`` to create persistent, mailbox-independent message identifiers.
/// Use ``EmailID`` for content-based message identification across mailboxes.
public struct UID: MessageIdentifier, Sendable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

/// A contiguous range of message UIDs.
///
/// `UIDRange` is a type alias for `MessageIdentifierRange<UID>`, representing
/// a contiguous sequence of unique message identifiers. See ``MessageIdentifierRange`` for detailed
/// documentation on range operations, construction, and wire format encoding.
///
/// See [RFC 3501 Section 2.3.1.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.1)
/// for UID definitions.
public typealias UIDRange = MessageIdentifierRange<UID>

/// A set of message UIDs, possibly non-contiguous.
///
/// `UIDSet` is a type alias for `MessageIdentifierSet<UID>`, representing
/// a collection of UIDs using optimized range storage. See ``MessageIdentifierSet``
/// for detailed documentation on set operations, construction, and wire format encoding.
///
/// See [RFC 3501 Section 6](https://datatracker.ietf.org/doc/html/rfc3501#section-6)
/// for message set syntax.
public typealias UIDSet = MessageIdentifierSet<UID>

/// A non-empty set of message UIDs.
///
/// `UIDSetNonEmpty` is a type alias for `MessageIdentifierSetNonEmpty<UID>`, representing
/// a collection of at least one UID guaranteed to be non-empty. See ``MessageIdentifierSetNonEmpty``
/// for detailed documentation on validation and usage in IMAP commands that require at least one message.
public typealias UIDSetNonEmpty = MessageIdentifierSetNonEmpty<UID>

// MARK: - Conversion

extension UID {
    public init(_ other: UnknownMessageIdentifier) {
        self.init(rawValue: other.rawValue)
    }
}

extension UnknownMessageIdentifier {
    public init(_ other: UID) {
        self.init(rawValue: other.rawValue)
    }
}
