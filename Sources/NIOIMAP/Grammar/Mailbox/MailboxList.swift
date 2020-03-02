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

extension NIOIMAP.Mailbox {
    
    /// IMAPv4 `mailbox-list`
    public struct List: Equatable {
        var flags: Flags?
        var char: Character?
        var mailbox: NIOIMAP.Mailbox
        var listExtended: ListExtended?
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeMailboxList(_ list: NIOIMAP.Mailbox.List) -> Int {
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
