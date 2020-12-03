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

/// A collection of mailbox attributes defined in the supported IMAP4 RFCs.
public struct MailboxInfo: Equatable {
    
    /// An array of mailbox attributes.
    public var attributes: [Attribute]
    
    /// The mailbox path.
    public var path: MailboxPath
    
    /// A catch-all to support any attributes added in future extensions.
    public var extensions: [ListExtendedItem]

    /// Creates a new `MailboxInfo` attribute collection.
    /// - parameter attributes: An array of mailbox attributes.
    /// - parameter path: The mailbox path.
    /// - parameter extensions: A catch-all to support any attributes added in future extensions.
    public init(attributes: [Attribute] = [], path: MailboxPath, extensions: [ListExtendedItem]) {
        self.attributes = attributes
        self.path = path
        self.extensions = extensions
    }
}

// MARK: - Types

extension MailboxInfo {
    
    /// A single attribute of a Mailbox
    public struct Attribute: Hashable {

        /// It is not possible to use this name as a selectable mailbox.
        public static var noSelect: Self { Self(_backing: #"\noselect"#) }
        
        /// The mailbox has been marked as "interesting" by the server. It probably contains new messages since the mailbox was selected.
        public static var marked: Self { Self(_backing: #"\marked"#) }
        
        /// The mailbox does not have any new messages since the mailbox was last selected.
        public static var unmarked: Self { Self(_backing: #"\unmarked"#) }
        
        /// The mailbox does not refer to an existing mailbox.
        public static var nonExistent: Self { Self(_backing: #"\nonexistent"#) }
        
        /// It is not possible for this mailbox to have children.
        public static var noInferiors: Self { Self(_backing: #"\noinferiors"#) }
        
        /// The mailbox has been subscribed to.
        public static var subscribed: Self { Self(_backing: #"\subscribed"#) }
        
        /// The mailbox is a remote mailbox.
        public static var remote: Self { Self(_backing: #"\remote"#) }
        
        /// The mailbox has child mailboxes.
        public static var hasChildren: Self { Self(_backing: #"\HasChildren"#) }
        
        /// The mailbox does not have child attributes.
        public static var hasNoChildren: Self { Self(_backing: #"\HasNoChildren"#) }

        var _backing: String
        
        init(_backing: String) {
            self._backing = _backing
        }

        /// Creates a new `Attribute`. It's often safer to use the predefined static helpers. The string provided will be lowercased.
        /// - parameter str: The string representation of the attribute. Note that this string will be lowercased.
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
