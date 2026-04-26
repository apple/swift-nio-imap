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

extension Command {
    /// Custom payload encoding for specialized command arguments.
    ///
    /// The `CustomCommandPayload` enum provides two encoding modes for command data,
    /// allowing flexibility in how custom or extension-specific command arguments are
    /// transmitted to the server. This is primarily used for protocol extensions that
    /// require special handling of raw bytes.
    ///
    /// **Use cases:**
    /// - Custom IMAP extensions with non-standard syntax
    /// - Debugging and testing with raw protocol data
    /// - Extensions requiring exact byte-for-byte transmission
    ///
    /// - SeeAlso: ``Command``, ``CommandStreamPart/tagged(_:)``
    public enum CustomCommandPayload: Hashable, Sendable {
        /// Encodes the buffer as an IMAP string (quoted or literal).
        ///
        /// The bytes are automatically encoded using the IMAP string format: if they
        /// contain spaces, special characters, or are too long, they are sent as a
        /// literal with `{size}\r\n` prefix followed by the raw bytes. Otherwise, they
        /// are sent as a quoted string with `"..."` syntax.
        ///
        /// The safer option when the payload should be treated as data rather
        /// than protocol syntax.
        ///
        /// ### Example
        ///
        /// ```
        /// .literal("hello world".utf8)  // Encodes as: {"11"}\r\nhello world
        /// .literal("test".utf8)          // Encodes as: "test"
        /// ```
        case literal(ByteBuffer)

        /// Encodes the buffer verbatim without any IMAP syntax encoding.
        ///
        /// The bytes are copied directly to the output buffer without any modification,
        /// quoting, or literal prefix. This should only be used when the buffer already
        /// contains properly formatted IMAP protocol syntax.
        ///
        /// **Caution:** Misuse of this case can produce invalid protocol messages.
        /// Only use when you are certain the buffer contains valid IMAP syntax.
        ///
        /// ### Example
        ///
        /// ```
        /// .verbatim("CUSTOM-KEYWORD (param1 param2)".utf8)  // Sent as-is
        /// ```
        case verbatim(ByteBuffer)
    }
}

// MARK: -

extension EncodeBuffer {
    /// Writes a `CustomCommandPayload` to the buffer ready to be sent to the network.
    /// - parameter stream: The `CustomCommandPayload` to write.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeCustomCommandPayload(_ payload: Command.CustomCommandPayload) -> Int {
        switch payload {
        case .literal(let literal):
            return self.writeIMAPString(literal)
        case .verbatim(let verbatim):
            return self.writeBytes(verbatim.readableBytesView)
        }
    }
}
