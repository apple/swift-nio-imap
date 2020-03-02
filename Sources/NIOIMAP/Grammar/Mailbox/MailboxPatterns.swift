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

extension NIOIMAP {

    /// IMAPv4 `mbox-or-pat`
    public enum MailboxPatterns: Equatable {
        case mailbox(Mailbox.ListMailbox)
        case pattern(Patterns)
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeMailboxPatterns(_ patterns: NIOIMAP.MailboxPatterns) -> Int {
        switch patterns {
        case .mailbox(let list):
            return self.writeIMAPString(list)
        case .pattern(let patterns):
            return self.writePatterns(patterns)
        }
    }

}
