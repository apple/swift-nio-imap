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

/// Return options that specify what additional data a `LIST` command should include for each matched mailbox (RFC 5819).
///
/// **Requires server capability:** ``Capability/listExtended``
///
/// These options control what information is returned by a `LIST` command for each matching mailbox,
/// beyond the standard mailbox name and attributes. Return options are defined in
/// [RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819) and [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
///
/// ### Example
///
/// ```
/// C: A001 LIST "" "%" RETURN (CHILDREN STATUS (MESSAGES UNSEEN))
/// S: * LIST (\HasChildren) "/" "Archive"
/// S: * STATUS "Archive" (MESSAGES 42 UNSEEN 5)
/// S: * LIST (\HasNoChildren) "/" "Drafts"
/// S: * STATUS "Drafts" (MESSAGES 12 UNSEEN 3)
/// S: A001 OK LIST completed
/// ```
///
/// The `RETURN (CHILDREN STATUS (...))` options cause the server to return child information
/// and mailbox status data. The `LIST` responses are ``Response/untagged(_:)`` cases, and the
/// `STATUS` responses are ``Response/untagged(_:)`` with ``ResponsePayload/mailboxData(_:)`` containing
/// ``MailboxData/status(_:_:)`` variants.
///
/// ## Related types
///
/// Return options are used with the ``Command/list(_:reference:_:_:)`` command.
/// See ``MailboxAttribute`` for the attributes returned in status responses.
///
/// - SeeAlso: [RFC 5819](https://datatracker.ietf.org/doc/html/rfc5819), [RFC 3501 Section 6.3.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.8)
public enum ReturnOption: Hashable, Sendable {
    /// The `SUBSCRIBED` return option causes `LIST` to return subscription state for all matching mailboxes.
    ///
    /// Used with the ``Command/list(_:reference:_:_:)`` command to include subscription information
    /// in the `LIST` responses. From [RFC 5819 Section 2](https://datatracker.ietf.org/doc/html/rfc5819#section-2).
    case subscribed

    /// The `CHILDREN` return option requests mailbox child information.
    ///
    /// Instructs the server to return information about which mailboxes have children
    /// (subfolders). The standard mailbox attributes `\HasChildren` and `\HasNoChildren`
    /// provide this information. From [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2).
    case children

    /// The `STATUS` return option requests mailbox status information.
    ///
    /// When this option is specified, the server MUST return untagged `STATUS` responses
    /// in addition to `LIST` responses for each matching mailbox. The specified attributes
    /// determine what status data is returned (for example, `MESSAGES`, `UNSEEN`, or `UIDVALIDITY`).
    /// From [RFC 5819 Section 2.1](https://datatracker.ietf.org/doc/html/rfc5819#section-2.1).
    case statusOption([MailboxAttribute])

    /// The `SPECIAL-USE` return option requests only mailboxes with special-use attributes.
    ///
    /// Filters `LIST` results to return only mailboxes marked with special-use attributes
    /// like `\All`, `\Archive`, `\Drafts`, `\Flagged`, `\Junk`, `\Sent`, or `\Trash`.
    /// From [RFC 6154 Section 3](https://datatracker.ietf.org/doc/html/rfc6154#section-3).
    case specialUse

    /// Catch-all for `LIST` return options defined in future extensions.
    ///
    /// Supports extension return options not yet defined in the standard.
    case optionExtension(KeyValue<OptionExtensionKind, OptionValueComp?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeReturnOption(_ option: ReturnOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .children:
            return self.writeString("CHILDREN")
        case .statusOption(let option):
            return self.writeMailboxOptions(option)
        case .optionExtension(let option):
            return self.writeOptionExtension(option)
        case .specialUse:
            return self.writeString("SPECIAL-USE")
        }
    }
}
