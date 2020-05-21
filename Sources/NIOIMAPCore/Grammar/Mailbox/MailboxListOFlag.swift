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

extension MailboxInfo {
    
    /// IMAPv4 `mbx-list-oflag`
    public enum OFlag: Equatable {
        case noInferiors
        case subscribed
        case remote
        case child(ChildMailboxFlag)
        case other(String)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxListOFlag(_ flag: MailboxInfo.OFlag) -> Int {
        switch flag {
        case .noInferiors:
            return self.writeString(#"\Noinferiors"#)
        case .subscribed:
            return self.writeString(#"\Subscribed"#)
        case .remote:
            return self.writeString(#"\Remote"#)
        case .child(let child):
            return self.writeChildMailboxFlag(child)
        case .other(let string):
            return self.writeString("\\\(string)")
        }
    }
}
