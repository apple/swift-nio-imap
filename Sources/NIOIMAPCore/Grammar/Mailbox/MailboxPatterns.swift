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

// mbx-or-pat
/// Extends the LIST command to allow multiple mailbox patterns
public enum MailboxPatterns: Hashable, Sendable {
    /// Match a single mailbox pattern
    case mailbox(ByteBuffer)

    /// Match multiple mailbox patterns
    case pattern([ByteBuffer])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxPatterns(_ patterns: MailboxPatterns) -> Int {
        switch patterns {
        case .mailbox(let list):
            return self.writeIMAPString(list)
        case .pattern(let patterns):
            return self.writePatterns(patterns)
        }
    }
}
