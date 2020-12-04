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

/// RFC 5465 - One or more mailboxes
public struct Mailboxes: Equatable {
    
    /// Array of at least one mailbox.
    public private(set) var content: [MailboxName]

    /// Creates a new `Mailboxes` - there must be at least one mail box in the set.
    /// - parameter mailboxes: One or more mailboxes.
    /// - returns: `nil` if `mailboxes` is empty, otherwise a new `Mailboxes`
    init?(_ mailboxes: [MailboxName]) {
        guard mailboxes.count >= 1 else {
            return nil
        }
        self.content = mailboxes
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult public mutating func writeMailboxes(_ mailboxes: Mailboxes) -> Int {
        self.writeArray(mailboxes.content) { (mailbox, buffer) -> Int in
            buffer.writeMailbox(mailbox)
        }
    }
}
