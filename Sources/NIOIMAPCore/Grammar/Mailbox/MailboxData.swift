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

extension MailboxName {
    /// IMAPv4 `mailbox-data`
    public enum Data: Equatable {
        case flags([Flag])
        case list(MailboxInfo)
        case lsub(MailboxInfo)
        case search([Int])
        case esearch(ESearchResponse)
        case status(MailboxName, MailboxStatus)
        case exists(Int)
        case recent(Int)
        case namespace(NamespaceResponse)
        case searchSort(SearchSortMailboxData)
    }
}

public struct SearchSortMailboxData: Equatable {
    public var identifiers: [Int]
    public var modificationSequence: SearchSortModificationSequence

    public init(identifiers: [Int], modificationSequence: SearchSortModificationSequence) {
        self.identifiers = identifiers
        self.modificationSequence = modificationSequence
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchSortMailboxData(_ data: SearchSortMailboxData?) -> Int {
        self.writeString("SEARCH") +
            self.writeIfExists(data, callback: { (data) -> Int in
                self.writeArray(data.identifiers, prefix: " ", separator: "", parenthesis: false) { (element, buffer) -> Int in
                        buffer.writeString("\(element)")
                } +
                    self.writeSpace() +
                    self.writeSearchSortModificationSequence(data.modificationSequence)
            })
    }

    @discardableResult mutating func writeMailboxData(_ data: MailboxName.Data) -> Int {
        switch data {
        case .flags(let flags):
            return self.writeMailboxData_flags(flags)
        case .list(let list):
            return self.writeMailboxData_list(list)
        case .lsub(let list):
            return self.writeMailboxData_lsub(list)
        case .search(let list):
            return self.writeMailboxData_search(list)
        case .esearch(let response):
            return self.writeESearchResponse(response)
        case .status(let mailbox, let status):
            return self.writeMailboxData_status(mailbox: mailbox, status: status)
        case .exists(let num):
            return self.writeString("\(num) EXISTS")
        case .recent(let num):
            return self.writeString("\(num) RECENT")
        case .namespace(let namespaceResponse):
            return self.writeNamespaceResponse(namespaceResponse)
        case .searchSort(let data):
            return self.writeSearchSortMailboxData(data)
        }
    }

    private mutating func writeMailboxData_search(_ list: [Int]) -> Int {
        self.writeString("SEARCH") +
            self.writeArray(list, separator: "", parenthesis: false) { (num, buffer) -> Int in
                buffer.writeString(" \(num)")
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
