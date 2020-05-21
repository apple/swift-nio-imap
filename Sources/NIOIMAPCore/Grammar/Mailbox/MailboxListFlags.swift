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
    /// IMAPv4 `mbx-list-flags`
    public struct Flags: Equatable {
        public var oFlags: [OFlag]
        public var sFlag: SFlag?

        public init(oFlags: [MailboxInfo.OFlag], sFlag: MailboxInfo.SFlag? = nil) {
            self.oFlags = oFlags
            self.sFlag = sFlag
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxListFlags(_ flags: MailboxInfo.Flags) -> Int {
        if let sFlag = flags.sFlag {
            return
                self.writeMailboxListSFlag(sFlag) +
                self.writeArray(flags.oFlags, separator: "", parenthesis: false) { (flag, self) in
                    self.writeSpace() +
                        self.writeMailboxListOFlag(flag)
                }
        } else {
            return self.writeArray(flags.oFlags, parenthesis: false) { (element, self) in
                self.writeMailboxListOFlag(element)
            }
        }
    }
}
