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

import NIO
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeMailboxData(_ data: IMAPCore.Mailbox.Data) -> Int {
        switch data {
        case .flags(let flags):
            return self.writeMailboxData_flags(flags)
        case .list(let list):
            return self.writeMailboxData_list(list)
        case .lsub(let list):
            return self.writeMailboxData_lsub(list)
        case .search(let response):
            return self.writeESearchResponse(response)
        case .status(let mailbox, let list):
            return self.writeMailboxData_status(mailbox: mailbox, list: list)
        case .exists(let num):
            return self.writeString("\(num) EXISTS")
        case .namespace(let namespaceResponse):
            return self.writeNamespaceResponse(namespaceResponse)
        }
    }
    
    private mutating func writeMailboxData_flags(_ flags: [IMAPCore.Flag]) -> Int {
        self.writeString("FLAGS ") +
        self.writeFlags(flags)
    }
    
    private mutating func writeMailboxData_list(_ list: IMAPCore.Mailbox.List) -> Int {
        self.writeString("LIST ") +
        self.writeMailboxList(list)
    }
    
    private mutating func writeMailboxData_lsub(_ list: IMAPCore.Mailbox.List) -> Int {
        self.writeString("LSUB ") +
        self.writeMailboxList(list)
    }
    
    private mutating func writeMailboxData_status(mailbox: IMAPCore.Mailbox, list: [IMAPCore.StatusAttributeValue]) -> Int {
        self.writeString("STATUS ") +
        self.writeMailbox(mailbox) +
        self.writeString(" (") +
        self.writeIfArrayHasMinimumSize(array: list) { (list, self) -> Int in
            self.writeStatusAttributeList(list)
        } +
        self.writeString(")")
    }

}
