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
            self.storage = ByteBuffer(ByteBufferView("INBOX".utf8))
        } else {
            self.storage = bytes
        }
    }

    /// Splits `mailbox` into constituent path components using the `PathSeparator`. Conversion is lossy and
    /// for display purposes only, do not use the return value as a mailbox name.
    /// The conversion to display string using heuristics to determine if the byte stream is the modified version of UTF-7 encoding defined in RFC 2152 (which is should be according to RFC 3501) — or if it is UTF-8 data. Many email clients erroneously encode mailbox names as UTF-8.
    /// - returns: [`String`] containing path components
    public func displayStringComponents(separator: Character, omittingEmptySubsequences: Bool = true) -> [String] {
        guard let first = separator.asciiValue else {
            preconditionFailure("Cannot split on a non-ascii character")
        }
        return self.storage.readableBytesView
            .split(separator: first, omittingEmptySubsequences: omittingEmptySubsequences)
            .map { String(decoding: $0, as: Unicode.UTF8.self) }
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
