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
import struct NIO.ByteBufferView

public struct MailboxPath: Equatable {
    public var name: MailboxName
    public var pathSeparator: Character?

    /// Creates a new `MailboxPath` with the given data.
    /// NOTE: Do not use this initialiser to create a root mailbox that requires validation. Instead us `createRootMailbox(displayName:, pathSeparator)`
    /// - parameter name: The `MailboxName` containing UTF-7 encoded bytes
    /// - parameter pathSeparator: An optional `Character` used to delimit sub-mailboxes.
    public init(name: MailboxName, pathSeparator: Character? = nil) {
        self.name = name
        self.pathSeparator = pathSeparator
    }
}

extension MailboxPath {
    
    /// Splits `mailbox` into constituent path components using the `PathSeparator`. Conversion is lossy and
    /// for display purposes only, do not use the return value as a mailbox name.
    /// The conversion to display string using heuristics to determine if the byte stream is the modified version of UTF-7 encoding defined in RFC 2152 (which it should be according to RFC 3501) — or if it is UTF-8 data. Many email clients erroneously encode mailbox names as UTF-8.
    /// - returns: [`String`] containing path components
    public func displayStringComponents(omittingEmptySubsequences: Bool = true) -> [String] {
        guard let first = self.pathSeparator?.asciiValue else {
            preconditionFailure("Cannot split on a non-ascii character")
        }
        return self.name.storage.readableBytesView
            .split(separator: first, omittingEmptySubsequences: omittingEmptySubsequences)
            .map { String(decoding: $0, as: Unicode.UTF8.self) }
    }
    
    /// Creates a new root mailbox. The given display string will be encoded according to RFC 2152
    /// and then vlaidate that there are no path separators in the name.
    /// - parameter displayName: The name of the new mailbox
    /// - parameter pathSeparator: The optional separator to delimit sub-mailboxes
    /// - returns: `nil` if the `displayName` contains a `pathSeparator`, otherwise a new `MailboxPath`
    public static func createRootMailbox(displayName: String, pathSeparator: Character? = nil) -> MailboxPath? {
        // the new name should not contain a path separator
        if let separator = pathSeparator, displayName.contains(separator) {
            return nil
        }
        let encodedNewName = ModifiedUTF7.encode(displayName)
        return MailboxPath(name: .init(encodedNewName), pathSeparator: pathSeparator)
    }
    
    /// Creates a new mailbox path that nested inside the existing path.
    ///
    /// This will encode the display string according to RFC 2152
    /// and make sure that there are no path separators in the name,
    /// and then append the path separator and the name to the
    /// existing path’s name.
    ///
    /// This should _only_ be used in order to create the path / name for a new mailbox
    /// that the client wants to create. It should not be used to create paths that already exist
    /// on the server. The reason is that mailboxes are identified by the exact byte sequence
    /// of their name. Re-assembling a path and doing the required encoding might produce
    /// different byte sequences if another client uses a bogus encoding. Sadly that is rather
    /// common.
    /// - parameter name: The name of the sub-mailbox to create, which will be UTF-7 encoded.
    /// - returns: `nil` if the sub-mailbox contains the `pathSeparator`, otherwise a new `MailboxPath`.
    public func createSubMailboxWithDisplayName(_ name: String) -> MailboxPath? {
        // the new name should not contain a path separator
        if let separator = self.pathSeparator, name.contains(separator) {
            return nil
        }

        var newStorage = self.name.storage
        if let separator = self.pathSeparator {
            newStorage.writeBytes(separator.utf8)
        }

        var encodedNewName = ModifiedUTF7.encode(name)
        newStorage.writeBuffer(&encodedNewName)
        return MailboxPath(name: .init(newStorage), pathSeparator: self.pathSeparator)
    }
}

/// IMAPv4 `mailbox`
public struct MailboxName: Equatable {
    public static var inbox = Self("INBOX")

    /// The raw bytes, readable as `[UInt8]`
    public var storage: ByteBuffer

    /// The raw bytes decoded into a UTF8 `String`
    public var stringValue: String {
        String(buffer: self.storage)
    }

    /// `true` if the internal storage reads "INBOX"
    /// otherwise `false`
    public var isInbox: Bool {
        storage.readableBytesView.lazy.map { $0 & 0xDF }.elementsEqual("INBOX".utf8)
    }

    /// Creates a new `MailboxName`. Note if the given string is some variation of "inbox" then we will uppercase it.
    /// - parameter string: The mailbox name
    public init(_ string: String) {
        if string.uppercased() == "INBOX" {
            self.storage = ByteBuffer(ByteBufferView("INBOX".utf8))
        } else {
            self.storage = ByteBuffer(ByteBufferView(string.utf8))
        }
    }

    public init(_ bytes: ByteBuffer) {
        if String(buffer: bytes).uppercased() == "INBOX" {
            self.storage = ByteBuffer(string: "INBOX")
        } else {
            self.storage = bytes
        }
    }
}

// MARK: - CustomStringConvertible

extension MailboxName: CustomStringConvertible {
    public var description: String {
        self.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult public mutating func writeMailbox(_ mailbox: MailboxName) -> Int {
        self.writeIMAPString(mailbox.storage)
    }
}
