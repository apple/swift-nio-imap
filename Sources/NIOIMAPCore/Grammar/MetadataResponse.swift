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

public enum MetadataResponse: Equatable {
    case values(values: [EntryValue], mailbox: MailboxName)
    case list(list: [ByteBuffer], mailbox: MailboxName)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataResponse(_ resp: MetadataResponse) -> Int {
        switch resp {
        case .values(values: let values, mailbox: let mailbox):
            return self.writeString("METADATA ") +
                self.writeMailbox(mailbox) +
                self.writeSpace() +
                self.writeEntryValues(values)
        case .list(list: let list, mailbox: let mailbox):
            return self.writeString("METADATA ") +
                self.writeMailbox(mailbox) +
                self.writeSpace() +
                self.writeEntryList(list)
        }
    }
}
