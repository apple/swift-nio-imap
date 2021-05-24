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
import struct OrderedCollections.OrderedDictionary

/// A collection of mailbox attributes defined in the supported IMAP4 RFCs.
public struct MailboxInfo: Equatable {
    /// An array of mailbox attributes.
    public var attributes: [Attribute]

    /// The mailbox path.
    public var path: MailboxPath

    /// A catch-all to support any attributes added in future extensions.
    public var extensions: OrderedDictionary<ByteBuffer, ParameterValue>

    /// Creates a new `MailboxInfo` attribute collection.
    /// - parameter attributes: An array of mailbox attributes.
    /// - parameter path: The mailbox path.
    /// - parameter extensions: A catch-all to support any attributes added in future extensions.
    public init(attributes: [Attribute] = [], path: MailboxPath, extensions: OrderedDictionary<ByteBuffer, ParameterValue>) {
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
        public static var noSelect: Self { Self(backing: #"\noselect"#) }

        /// The mailbox has been marked as "interesting" by the server. It probably contains new messages since the mailbox was selected.
        public static var marked: Self { Self(backing: #"\marked"#) }

        /// The mailbox does not have any new messages since the mailbox was last selected.
        public static var unmarked: Self { Self(backing: #"\unmarked"#) }

        /// The mailbox does not refer to an existing mailbox.
        public static var nonExistent: Self { Self(backing: #"\nonexistent"#) }

        /// It is not possible for this mailbox to have children.
        public static var noInferiors: Self { Self(backing: #"\noinferiors"#) }

        /// The mailbox has been subscribed to.
        public static var subscribed: Self { Self(backing: #"\subscribed"#) }

        /// The mailbox is a remote mailbox.
        public static var remote: Self { Self(backing: #"\remote"#) }

        /// The mailbox has child mailboxes.
        public static var hasChildren: Self { Self(backing: #"\HasChildren"#) }

        /// The mailbox does not have child attributes.
        public static var hasNoChildren: Self { Self(backing: #"\HasNoChildren"#) }

        fileprivate var backing: String

        init(backing: String) {
            self.backing = backing
        }

        /// Creates a new `Attribute`. It's often safer to use the predefined static helpers. The string provided will be lowercased.
        /// - parameter str: The string representation of the attribute. Note that this string will be lowercased.
        public init(_ str: String) {
            self.backing = str.lowercased()
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    private mutating func writeMailboxPathSeparator(_ character: Character?) -> Int {
        switch character {
        case nil:
            return self.writeNil()
        case "\\":
            return self.writeString(#""\""#)
        case "\"":
            return self.writeString(#""\\""#)
        case let character?:
            return self.writeString("\"\(character)\"")
        }
    }

    @discardableResult mutating func writeMailboxInfo(_ list: MailboxInfo) -> Int {
        self.writeString("(") +
            self.writeIfExists(list.attributes) { (flags) -> Int in
                self.writeMailboxListFlags(flags)
            } +
            self.writeString(") ") +
            self.writeMailboxPathSeparator(list.path.pathSeparator) +
            self.writeSpace() +
            self.writeMailbox(list.path.name)
    }

    @discardableResult mutating func writeMailboxListFlags(_ flags: [MailboxInfo.Attribute]) -> Int {
        self.writeArray(flags, parenthesis: false) { (element, self) in
            self.writeString(element.backing)
        }
    }
}
