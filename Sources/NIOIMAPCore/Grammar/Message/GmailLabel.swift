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

/// A Gmail label identifier (vendor extension).
///
/// Gmail treats labels like mailbox folders. This type represents a single Gmail label returned
/// in the X-GM-LABELS attribute of a FETCH response. Labels are stored as byte buffers and may be
/// encoded in modified UTF-7 format (the same encoding used for mailbox names).
///
/// A Gmail-specific extension not part of the standard IMAP protocol. It is available when
/// the server advertises the X-GM-EXT-1 capability.
///
/// ### Example
///
/// ```
/// C: A001 FETCH 1 (X-GM-LABELS)
/// S: * 1 FETCH (X-GM-LABELS ("Important" "Work"))
/// ```
///
/// The response indicates message 1 has two labels: "Important" and "Work".
///
/// - SeeAlso: [Gmail IMAP Extensions](https://developers.google.com/gmail/imap/imap-extensions)
/// - SeeAlso: ``MessageAttribute/gmailLabels(_:)``
public struct GmailLabel: Hashable, Sendable {
    /// The label's raw value -  a sequence of bytes
    let buffer: ByteBuffer

    /// Creates a new `GmailLabel` from the given bytes.
    /// - parameter buffer: The raw bytes to construct the label
    public init(_ buffer: ByteBuffer) {
        self.buffer = buffer
    }

    /// Creates a new `GmailLabel` from the given `MailboxName`.
    public init(mailboxName: MailboxName) {
        self.buffer = ByteBuffer(bytes: mailboxName.bytes)
    }

    /// Creates a new `GmailLabel` from the given `UseAttribute`.
    public init(useAttribute: UseAttribute) {
        self.buffer = ByteBuffer(string: useAttribute.stringValue)
    }

    /// Creates a display string to be used in UI.
    ///
    /// Note that the conversion may be lossy. This will
    /// attempt to decode as “modified UTF-7”, and fall
    /// back to lossy UTF-8 decoding.
    public func makeDisplayString() -> String {
        do {
            return try ModifiedUTF7.decode(self.buffer)
        } catch {
            return String(bestEffortDecodingUTF8Bytes: self.buffer.readableBytesView)
        }
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeGmailLabels(_ labels: [GmailLabel]) -> Int {
        self.writeArray(labels) { (label, self) -> Int in
            self.writeGmailLabel(label)
        }
    }

    @discardableResult mutating func writeGmailLabel(_ label: GmailLabel) -> Int {
        guard label.buffer.getInteger(at: label.buffer.readerIndex) == UInt8(ascii: "\\") else {
            return self.writeIMAPString(label.buffer)
        }
        var stringValue = label.buffer
        return self.writeBuffer(&stringValue)
    }
}
