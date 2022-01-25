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

/// Mailbox attributes with associated data, part of a fetch response.
public enum MailboxData: Hashable {
    /// The flags associated with a mailbox.
    case flags([Flag])

    /// Mailbox attributes.
    case list(MailboxInfo)

    /// Subscribed mailbox attributes.
    case lsub(MailboxInfo)

    /// Response to a search command, containing `SequenceNumber`s from `search`, or `UID`s from `uid search`.
    case search([UnknownMessageIdentifier], ModificationSequenceValue? = nil)

    /// Response to an extended search command.
    case extendedSearch(ExtendedSearchResponse)

    /// The status of the given Mailbox.
    case status(MailboxName, MailboxStatus)

    /// The number of messages in a mailbox.
    case exists(Int)

    /// The number of messages with the *\\Recent* flag set.
    case recent(Int)

    /// Response to a namespace command.
    case namespace(NamespaceResponse)

    /// Response to a search-sort command, containing an array of identifiers and sequence information.
    case searchSort(SearchSort)
}

extension MailboxData {
    /// A container for an array of message identifiers, and a sequence.
    public struct SearchSort: Hashable {
        /// An array of message identifiers that were matched in a search.
        public var identifiers: [Int]

        /// The highest `ModificationSequence` of all messages that were found.
        public var modificationSequence: ModificationSequenceValue

        /// Creates a new `SearchSort`.
        /// - parameter identifiers: An array of message identifiers that were matched in a search.
        /// - parameter modificationSequence: The highest `ModificationSequence` of all messages that were found.
        public init(identifiers: [Int], modificationSequence: ModificationSequenceValue) {
            self.identifiers = identifiers
            self.modificationSequence = modificationSequence
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxDataSearchSort(_ data: MailboxData.SearchSort?) -> Int {
        self.writeString("SEARCH") +
            self.writeIfExists(data) { (data) -> Int in
                self.writeArray(data.identifiers, prefix: " ", parenthesis: false) { (element, buffer) -> Int in
                    buffer.writeString("\(element)")
                } +
                    self.writeSpace() +
                    self.writeString("(MODSEQ ") +
                    self.writeModificationSequenceValue(data.modificationSequence) +
                    self.writeString(")")
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
        }
    }

    private mutating func writeMailboxData_search(_ list: [UnknownMessageIdentifier], modificationSequence: ModificationSequenceValue?) -> Int {
        self.writeString("SEARCH") +
            self.writeArray(list, separator: " ", parenthesis: false) { (id, buffer) -> Int in
                buffer.writeMessageIdentifier(id)
            } +
            self.writeIfExists(modificationSequence) { value -> Int in
                self.writeString(" (MODSEQ ") +
                    self.writeModificationSequenceValue(value) +
                    self.writeString(")")
            }
    }

    private mutating func writeMailboxData_flags(_ flags: [Flag]) -> Int {
        self.writeString("FLAGS ") +
            self.writeFlags(flags)
    }

    private mutating func writeMailboxData_list(_ list: MailboxInfo) -> Int {
        self.writeString("LIST ") +
            self.writeMailboxInfo(list)
    }

    private mutating func writeMailboxData_lsub(_ list: MailboxInfo) -> Int {
        self.writeString("LSUB ") +
            self.writeMailboxInfo(list)
    }

    private mutating func writeMailboxData_status(mailbox: MailboxName, status: MailboxStatus) -> Int {
        self.writeString("STATUS ") +
            self.writeMailbox(mailbox) +
            self.writeString(" (") +
            self.writeMailboxStatus(status) +
            self.writeString(")")
    }
}
