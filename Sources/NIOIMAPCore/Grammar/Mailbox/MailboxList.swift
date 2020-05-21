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
    /// IMAPv4 `mailbox-list`
    public struct MailboxInfo: Equatable {
        public var flags: Flags?
        public var char: Character?
        public var mailbox: MailboxName
        public var listExtended: [ListExtendedItem]

        public init(flags: MailboxName.MailboxInfo.Flags? = nil, char: Character? = nil, mailbox: MailboxName, listExtended: [MailboxName.ListExtendedItem]) {
            self.flags = flags
            self.char = char
            self.mailbox = mailbox
            self.listExtended = listExtended
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxInfo(_ list: MailboxName.MailboxInfo) -> Int {
        self.writeString("(") +
            self.writeIfExists(list.flags) { (flags) -> Int in
                self.writeMailboxListFlags(flags)
            } +
            self.writeString(") ") +
            self.writeIfExists(list.char) { (char) -> Int in
                self.writeString("\(char) ")
            } +
            self.writeMailbox(list.mailbox)
    }
}
