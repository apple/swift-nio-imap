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
    public var attributes: Attributes?
    public var pathSeparator: Character?
    public var mailbox: MailboxName
    public var extensions: [ListExtendedItem]

    public init(attributes: Attributes? = nil, pathSeparator: Character? = nil, mailbox: MailboxName, extensions: [ListExtendedItem]) {
        self.attributes = attributes
        self.pathSeparator = pathSeparator
        self.mailbox = mailbox
        self.extensions = extensions
    }
}

// MARK: - Types

extension MailboxInfo {
    /// IMAPv4 `mbx-list-sflag`
    public enum SFlag: String, Equatable {
        case noSelect = #"\Noselect"#
        case marked = #"\Marked"#
        case unmarked = #"\Unmarked"#
        case nonExistent = #"\Nonexistent"#

        public init?(rawValue: String) {
            switch rawValue.lowercased() {
            case #"\noselect"#:
                self = .noSelect
            case #"\marked"#:
                self = .marked
            case #"\unmarked"#:
                self = .unmarked
            case #"\nonexistent"#:
                self = .nonExistent
            default:
                return nil
            }
        }
    }

    /// IMAPv4 `mbx-list-oflag`
    public enum OFlag: Equatable {
        case noInferiors
        case subscribed
        case remote
        case child(ChildMailboxFlag)
        case other(String)
    }

    /// IMAPv4 `mbx-list-flags`
    public struct Attributes: Equatable {
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
    @discardableResult mutating func writeMailboxInfo(_ list: MailboxInfo) -> Int {
        self.writeString("(") +
            self.writeIfExists(list.attributes) { (flags) -> Int in
                self.writeMailboxListFlags(flags)
            } +
            self.writeString(") ") +
            self.writeIfExists(list.pathSeparator) { (char) -> Int in
                self.writeString("\(char) ")
            } +
            self.writeMailbox(list.mailbox)
    }

    @discardableResult mutating func writeMailboxListSFlag(_ flag: MailboxInfo.SFlag) -> Int {
        self.writeString(flag.rawValue)
    }

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

    @discardableResult mutating func writeMailboxListFlags(_ flags: MailboxInfo.Attributes) -> Int {
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
