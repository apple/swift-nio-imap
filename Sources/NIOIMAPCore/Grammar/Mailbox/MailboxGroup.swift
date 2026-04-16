//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

/// A group of email addresses.
///
/// ``EmailAddressGroup`` represents an RFC 5322 address group within a message envelope.
/// Address groups provide a way to collect multiple email addresses under a single name,
/// allowing the `ENVELOPE` structure to represent complex address lists including both
/// individual addresses and named groups.
///
/// Per [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2),
/// the envelope structure includes address lists that may contain address groups.
/// An address group is delimited by a group-start and group-end line in the wire format,
/// with a group name and optional source root.
///
/// ### Example
///
/// ```
/// S: * 1 FETCH (ENVELOPE (NIL "Subject" ... ((NIL "Group Name" NIL NIL)
///              ("user1" NIL "user1" "example.com")
///              ("user2" NIL "user2" "example.com")
///              (NIL NIL NIL NIL)) NIL NIL NIL NIL))
/// ```
///
/// The group start/end are implicit in the nested structure. The group name and children
/// are wrapped in ``EmailAddressGroup``, and child addresses appear as ``EmailAddressListElement/singleAddress(_:)``
/// cases within ``children``.
///
/// - SeeAlso: ``EmailAddress``, ``EmailAddressListElement``, ``Envelope``
public struct EmailAddressGroup: Hashable, Sendable {
    /// The name of the address group.
    ///
    /// This is the human-readable name for the collection of addresses, such as "Family" or "Work Team".
    public var groupName: ByteBuffer

    /// The optional source root for the address group.
    ///
    /// This field may contain additional routing information for the group.
    /// Per [RFC 5322](https://datatracker.ietf.org/doc/html/rfc5322), this is typically `nil`.
    public var sourceRoot: ByteBuffer?

    /// The nested addresses and groups within this group.
    ///
    /// This list can contain both individual addresses (``EmailAddressListElement/singleAddress(_:)``)
    /// and nested address groups (``EmailAddressListElement/group(_:)``), allowing for arbitrarily
    /// deep hierarchies.
    public var children: [EmailAddressListElement]

    /// Creates a new address group.
    ///
    /// - Parameter groupName: The name of the group
    /// - Parameter sourceRoot: Optional source root for routing information
    /// - Parameter children: The nested addresses and groups
    public init(groupName: ByteBuffer, sourceRoot: ByteBuffer?, children: [EmailAddressListElement]) {
        self.groupName = groupName
        self.sourceRoot = sourceRoot
        self.children = children
    }
}

/// An element within an email address list that can be either a single address or a group.
///
/// ``EmailAddressListElement`` is used in message envelopes to represent the flexible structure of
/// RFC 5322 address lists. Per [RFC 3501 Section 7.4.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.4.2),
/// the ENVELOPE structure includes address lists (such as `To:`, `From:`, `Cc:`) that may contain
/// both individual email addresses and named address groups.
///
/// This is an indirect enum, allowing arbitrarily deep nesting of groups within groups.
///
/// ### Example
///
/// ```
/// // Simple address
/// * 1 FETCH (ENVELOPE (...(("John Doe" NIL "john" "example.com")) ...))
///
/// // Address group
/// * 1 FETCH (ENVELOPE (...((NIL "Friends" NIL NIL)
///              ("alice" NIL "alice" "example.com")
///              ("bob" NIL "bob" "example.com")
///              (NIL NIL NIL NIL)) ...))
/// ```
///
/// Single addresses map to ``EmailAddressListElement/singleAddress(_:)`` cases,
/// and groups map to ``EmailAddressListElement/group(_:)`` cases containing the group name
/// and nested ``EmailAddressListElement`` children.
///
/// - SeeAlso: ``EmailAddress``, ``EmailAddressGroup``, ``Envelope``
public indirect enum EmailAddressListElement: Hashable, Sendable {
    /// A single email address with no children.
    ///
    /// This case wraps a single ``EmailAddress`` in the address list.
    case singleAddress(EmailAddress)

    /// A collection of addresses organized under a group name.
    ///
    /// This case wraps an ``EmailAddressGroup`` containing a group name and nested
    /// ``EmailAddressListElement`` children (which can themselves be addresses or groups).
    case group(EmailAddressGroup)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEmailAddressGroup(_ group: EmailAddressGroup) -> Int {
        self.writeEmailAddress(
            .init(
                personName: nil,
                sourceRoot: group.sourceRoot,
                mailbox: group.groupName,
                host: nil
            )
        )
            + self.writeArray(group.children, prefix: "", separator: "", suffix: "", parenthesis: false) {
                (child, self) in
                self.writeEmailAddressOrGroup(child)
            }
            + self.writeEmailAddress(
                .init(
                    personName: nil,
                    sourceRoot: group.sourceRoot,
                    mailbox: nil,
                    host: nil
                )
            )
    }

    @discardableResult mutating func writeEmailAddressOrGroup(_ aog: EmailAddressListElement) -> Int {
        switch aog {
        case .singleAddress(let address):
            return self.writeEmailAddress(address)
        case .group(let group):
            return self.writeEmailAddressGroup(group)
        }
    }
}
