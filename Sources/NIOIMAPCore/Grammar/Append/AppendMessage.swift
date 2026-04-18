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

/// Metadata for a message being appended to a mailbox.
///
/// An `AppendMessage` combines optional metadata (flags, delivery date, extensions)
/// with information about the message data itself (size, encoding). This is sent
/// with each message in a multi-message `APPEND` command (RFC 3501), and can be
/// used with the `CATENATE` extension (RFC 4469) to specify metadata for catenated
/// messages.
///
/// ### Example
///
/// ```
/// C: A001 APPEND INBOX (\Seen) "17-Jul-1996 09:01:33 -0700" {1234}
/// S: + Ready for literal data
/// C: <1234 bytes of message data>
/// S: * 10 EXISTS
/// S: A001 OK APPEND completed
/// ```
///
/// The line `(\Seen) "17-Jul-1996 09:01:33 -0700" {1234}` corresponds to an `AppendMessage`
/// with flags and internal date in ``options``, and byte count and encoding mode in ``data``.
///
/// - SeeAlso: [RFC 3501 Section 6.3.11](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.11) (APPEND Command)
/// - SeeAlso: [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) (CATENATE Extension)
/// - SeeAlso: ``AppendOptions``, ``AppendData``, ``AppendCommand/beginMessage(message:)``
public struct AppendMessage: Hashable, Sendable {
    /// Optional flags, dates, and extension fields for the message.
    ///
    /// Contains zero or more metadata items to be associated with the message when
    /// it is appended, such as `\Seen`, `\Flagged`, the internal date, and any
    /// extension-specific fields.
    ///
    /// - SeeAlso: ``AppendOptions``
    public var options: AppendOptions

    /// Metadata about the message data itself (size and encoding).
    ///
    /// Specifies the number of bytes to be streamed and whether they should be sent
    /// as binary data (RFC 3516) or standard MIME-encoded data.
    ///
    /// - SeeAlso: ``AppendData``
    public var data: AppendData

    /// Creates a new message to append.
    ///
    /// - parameter options: Optional metadata (flags, date, extensions). Defaults to empty.
    /// - parameter data: Information about the message data (byte count, encoding mode)
    public init(options: AppendOptions, data: AppendData) {
        self.options = options
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    /// Writes an `AppendMessage` ready to be sent.
    /// - parameter `message`: The `AppendMessage` to write.
    /// - returns: The number of bytes written.
    @discardableResult mutating func writeAppendMessage(_ message: AppendMessage) -> Int {
        self.writeAppendOptions(message.options) + self.writeSpace() + self.writeAppendData(message.data)
    }
}
