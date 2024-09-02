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

/// GMail treats labels as folders.
public struct GmailLabel: Hashable, Sendable {
    /// The label's raw value -  a sequence of bytes
    let buffer: ByteBuffer

    /// Creates a new `GmailLabel` from the given bytes.
    /// - parameter rawValue: The raw bytes to construct the label
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
        if label.buffer.getInteger(at: label.buffer.readerIndex) == UInt8(ascii: "\\") {
            var stringValue = label.buffer
            return self.writeBuffer(&stringValue)
        } else {
            return self.writeIMAPString(label.buffer)
        }
    }
}
