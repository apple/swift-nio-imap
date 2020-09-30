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

/// IMAPv4 `mailbox-list`
public struct MailboxInfo: Equatable {
    public var attributes: [Attribute]
    public var path: MailboxPath
    public var extensions: [ListExtendedItem]

    public init(attributes: [Attribute] = [], path: MailboxPath, extensions: [ListExtendedItem]) {
        self.attributes = attributes
        self.path = path
        self.extensions = extensions
    }
}

// MARK: - Types

extension MailboxInfo {
    public struct Attribute: Hashable {
        var _backing: String

        public static var noSelect: Self { Self(_backing: #"\noselect"#) }
        public static var marked: Self { Self(_backing: #"\marked"#) }
        public static var unmarked: Self { Self(_backing: #"\unmarked"#) }
        public static var nonExistent: Self { Self(_backing: #"\nonexistent"#) }
        public static var noInferiors: Self { Self(_backing: #"\noinferiors"#) }
        public static var subscribed: Self { Self(_backing: #"\subscribed"#) }
        public static var remote: Self { Self(_backing: #"\remote"#) }
        public static var hasChildren: Self { Self(_backing: #"\HasChildren"#) }
        public static var hasNoChildren: Self { Self(_backing: #"\HasNoChildren"#) }

        init(_backing: String) {
            self._backing = _backing
        }

        public init(_ str: String) {
            self._backing = str.lowercased()
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxInfo(_ list: MailboxInfo) -> Int {
        self.writeString("(") +
            self.writeIfExists(list.attributes) { (flags) -> Int in
                self.writeMailboxListFlags(flags)
            } +
            self.writeString(") ") +
            self.writeIfExists(list.path.pathSeparator) { (char) -> Int in
                self.writeString("\(char) ")
            } +
            self.writeMailbox(list.path.name)
    }

    @discardableResult mutating func writeMailboxListFlags(_ flags: [MailboxInfo.Attribute]) -> Int {
        self.writeArray(flags, parenthesis: false) { (element, self) in
            self.writeString(element._backing)
        }
    }
}
