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

/// Untagged response data from the server about mailboxes, messages, or search results.
///
/// Servers send untagged responses (prefixed with `*`) that convey information about mailboxes, messages, and operation results.
/// This enum represents the various types of mailbox-related untagged data that a server can send.
///
/// These responses are typically encountered as the data within ``Response`` untagged responses, which may
/// be wrapped in ``ResponsePayload/mailboxData(_:)``.
public enum MailboxData: Hashable, Sendable {
    /// Response to a ``Command/select(_:_:)`` or ``Command/examine(_:_:)`` command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/flags(_:)``.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft \Junk)
    /// ```
    ///
    /// The line `S: * FLAGS...` is wrapped as ``MailboxData/flags(_:)`` containing an array of ``Flag`` values.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
    case flags([Flag])

    /// Response to a ``Command/list(_:reference:_:_:)`` or ``Command/listIndependent(_:reference:_:_:)`` command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/list(_:)``.
    ///
    /// ### Examples
    ///
    /// ```
    /// S: * LIST (\HasNoChildren) "/" "INBOX"
    /// S: * LIST (\HasChildren) "/" "Archive"
    /// ```
    ///
    /// Each line is wrapped as ``MailboxData/list(_:)`` containing a ``MailboxInfo`` with attributes and name.
    ///
    /// See ``MailboxInfo`` for the structure of the returned data.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.2.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.2)
    case list(MailboxInfo)

    /// Response to a ``Command/lsub(reference:pattern:)`` command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/lsub(_:)``.
    ///
    /// ### Examples
    ///
    /// ```
    /// S: * LSUB (\HasNoChildren) "/" "INBOX"
    /// S: * LSUB (\HasChildren) "/" "Projects"
    /// ```
    ///
    /// Each line is wrapped as ``MailboxData/lsub(_:)`` containing a ``MailboxInfo`` with subscribed mailbox information.
    ///
    /// See ``MailboxInfo`` for the structure of the returned data.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.2.3](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.3)
    case lsub(MailboxInfo)

    /// Response to a ``Command/search(key:charset:returnOptions:)`` or ``Command/uidSearch(key:charset:returnOptions:)`` command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/search(_:_:)``.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 SEARCH ALL
    /// S: * SEARCH 1 3 5 7 9
    /// S: A001 OK SEARCH completed
    /// ```
    ///
    /// The line `S: * SEARCH 1 3 5 7 9` is wrapped as ``MailboxData/search(_:_:)`` containing an array
    /// of message identifiers matching the search criteria.
    ///
    /// When the ``ModificationSequenceValue`` is present (with [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162)
    /// CONDSTORE support), it indicates the highest modification sequence number among all matching messages.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.2.5](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.5)
    case search([UnknownMessageIdentifier], ModificationSequenceValue? = nil)

    /// Response to a search command using the ESEARCH extension.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/extendedSearch(_:)``.
    ///
    /// See ``ExtendedSearchResponse`` for the structure of the returned data.
    ///
    /// - SeeAlso: [RFC 4731](https://datatracker.ietf.org/doc/html/rfc4731) - ESEARCH Extension
    case extendedSearch(ExtendedSearchResponse)

    /// Response to a ``Command/status(_:_:)`` command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/status(_:_:)``.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 STATUS "INBOX" (MESSAGES UNSEEN UIDVALIDITY)
    /// S: * STATUS "INBOX" (MESSAGES 42 UNSEEN 3 UIDVALIDITY 1234567890)
    /// S: A001 OK STATUS completed
    /// ```
    ///
    /// The line `S: * STATUS "INBOX"...` is wrapped as ``MailboxData/status(_:_:)`` containing the
    /// mailbox name and a ``MailboxStatus`` with the requested status attributes (`MESSAGES`, `UNSEEN`, `UIDVALIDITY`).
    ///
    /// - SeeAlso: [RFC 3501 Section 7.2.4](https://datatracker.ietf.org/doc/html/rfc3501#section-7.2.4)
    case status(MailboxName, MailboxStatus)

    /// The number of messages in the currently selected mailbox.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/exists(_:)``.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 42 EXISTS
    /// ```
    ///
    /// The line `S: * 42 EXISTS` is wrapped as ``MailboxData/exists(_:)`` with the count `42`.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.3.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.1)
    case exists(Int)

    /// The number of messages with the `\Recent` flag set.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/recent(_:)``.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 3 RECENT
    /// ```
    ///
    /// The line `S: * 3 RECENT` is wrapped as ``MailboxData/recent(_:)`` with the count `3`.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.3.2](https://datatracker.ietf.org/doc/html/rfc3501#section-7.3.2)
    case recent(Int)

    /// Response to a NAMESPACE command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/namespace(_:)``.
    ///
    /// See ``NamespaceResponse`` for the structure of the returned data.
    ///
    /// - SeeAlso: [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342) - NAMESPACE Extension
    case namespace(NamespaceResponse)

    /// Response to a search command with SORT or THREAD extensions.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/searchSort(_:)``.
    ///
    /// See ``SearchSort`` for the structure of the returned data.
    ///
    /// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256) - SORT and THREAD Extensions
    case searchSort(SearchSort)

    /// Response to a UID BATCHES command.
    ///
    /// Sent as part of ``ResponsePayload/mailboxData(_:)`` containing ``MailboxData/uidBatches(_:)``.
    ///
    /// See ``UIDBatchesResponse`` for the structure of the returned data.
    ///
    /// - SeeAlso: [IMAP UID BATCHES Draft](https://datatracker.ietf.org/doc/draft-ietf-mailmaint-imap-uidbatches/)
    case uidBatches(UIDBatchesResponse)
}

extension MailboxData {
    /// Search results from SORT or THREAD operations.
    ///
    /// Provides sorted or threaded message identifiers along with the highest modification sequence among
    /// matching messages. Used with the [SORT](https://datatracker.ietf.org/doc/html/rfc5256) and
    /// [THREAD](https://datatracker.ietf.org/doc/html/rfc5256) extensions.
    ///
    /// - SeeAlso: [RFC 5256](https://datatracker.ietf.org/doc/html/rfc5256) - SORT and THREAD Extensions
    public struct SearchSort: Hashable, Sendable {
        /// An array of message identifiers from the sort or thread operation.
        public var identifiers: [Int]

        /// The highest modification sequence value among all matched messages.
        ///
        /// Used with [RFC 7162](https://datatracker.ietf.org/doc/html/rfc7162) CONDSTORE support to
        /// indicate if any matching messages have been modified since the last synchronization.
        public var modificationSequence: ModificationSequenceValue

        /// Creates a new `SearchSort`.
        /// - parameter identifiers: An array of message identifiers that were matched in a search or sort operation.
        /// - parameter modificationSequence: The highest modification sequence value among all matched messages.
        public init(identifiers: [Int], modificationSequence: ModificationSequenceValue) {
            self.identifiers = identifiers
            self.modificationSequence = modificationSequence
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxDataSearchSort(_ data: MailboxData.SearchSort?) -> Int {
        self.writeString("SEARCH")
            + self.writeIfExists(data) { (data) -> Int in
                self.writeArray(data.identifiers, prefix: " ", parenthesis: false) { (element, buffer) -> Int in
                    buffer.writeString("\(element)")
                } + self.writeSpace() + self.writeString("(MODSEQ ")
                    + self.writeModificationSequenceValue(data.modificationSequence) + self.writeString(")")
            }
    }

    @discardableResult mutating func writeMailboxData(_ data: MailboxData) -> Int {
        switch data {
        case .flags(let flags):
            return self.writeMailboxData_flags(flags)
        case .list(let list):
            return self.writeMailboxData_list(list)
        case .lsub(let list):
            return self.writeMailboxData_lsub(list)
        case .search(let list, let modificationSequence):
            return self.writeMailboxData_search(list, modificationSequence: modificationSequence)
        case .extendedSearch(let response):
            return self.writeExtendedSearchResponse(response)
        case .status(let mailbox, let status):
            return self.writeMailboxData_status(mailbox: mailbox, status: status)
        case .exists(let num):
            return self.writeString("\(num) EXISTS")
        case .recent(let num):
            return self.writeString("\(num) RECENT")
        case .namespace(let namespaceResponse):
            return self.writeNamespaceResponse(namespaceResponse)
        case .searchSort(let data):
            return self.writeMailboxDataSearchSort(data)
        case .uidBatches(let response):
            return self.writeUIDBatchesResponse(response)
        }
    }

    private mutating func writeMailboxData_search(
        _ list: [UnknownMessageIdentifier],
        modificationSequence: ModificationSequenceValue?
    ) -> Int {
        self.writeString("SEARCH")
            + self.writeArray(list, prefix: " ", separator: " ", parenthesis: false) { (id, buffer) -> Int in
                buffer.writeMessageIdentifier(id)
            }
            + self.writeIfExists(modificationSequence) { value -> Int in
                self.writeString(" (MODSEQ ") + self.writeModificationSequenceValue(value) + self.writeString(")")
            }
    }

    private mutating func writeMailboxData_flags(_ flags: [Flag]) -> Int {
        self.writeString("FLAGS ") + self.writeFlags(flags)
    }

    private mutating func writeMailboxData_list(_ list: MailboxInfo) -> Int {
        self.writeString("LIST ") + self.writeMailboxInfo(list)
    }

    private mutating func writeMailboxData_lsub(_ list: MailboxInfo) -> Int {
        self.writeString("LSUB ") + self.writeMailboxInfo(list)
    }

    private mutating func writeMailboxData_status(mailbox: MailboxName, status: MailboxStatus) -> Int {
        self.writeString("STATUS ") + self.writeMailbox(mailbox) + self.writeString(" (")
            + self.writeMailboxStatus(status) + self.writeString(")")
    }
}
