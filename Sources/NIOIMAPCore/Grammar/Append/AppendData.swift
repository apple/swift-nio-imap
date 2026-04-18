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

/// Message data metadata for an `APPEND` command.
///
/// An `AppendData` specifies the size and encoding of message bytes being appended to
/// a mailbox. It determines whether the data is sent using the `BINARY` extension
/// (RFC 3516) for raw 8-bit binary data (potentially containing NUL octets), or as
/// standard MIME content-transfer-encoded data.
///
/// ### Example
///
/// ```
/// C: A001 APPEND INBOX {1234}
/// S: + Ready for literal data
/// C: <1234 bytes of message data>
/// S: * 10 EXISTS
/// S: A001 OK APPEND completed
/// ```
///
/// The `{1234}` declares the message size and is represented as `AppendData(byteCount: 1234)`.
///
/// With the `BINARY` extension (RFC 3516) for 8-bit data:
/// ```
/// C: A001 APPEND INBOX ~{1234}
/// S: + Ready for literal data
/// C: <1234 bytes of binary data (may contain NUL octets)>
/// ```
///
/// The `~{1234}` is represented as `AppendData(byteCount: 1234, withoutContentTransferEncoding: true)`.
///
/// - SeeAlso: [RFC 3501 Section 4.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3) (Literals)
/// - SeeAlso: [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516) (BINARY Extension)
/// - SeeAlso: [RFC 7888](https://datatracker.ietf.org/doc/html/rfc7888) (Non-synchronizing Literals)
/// - SeeAlso: ``AppendMessage``, ``AppendCommand/beginMessage(message:)``
public struct AppendData: Hashable, Sendable {
    /// The size of the message in bytes.
    ///
    /// This exact number of bytes must be streamed after the protocol sends a
    /// continuation request (`+`). If fewer or more bytes are sent, the protocol
    /// enters an undefined state.
    public var byteCount: Int

    /// Whether the data is binary 8-bit data without MIME content-transfer-encoding.
    ///
    /// When `true`, the data is sent using the `~{size}` literal syntax (RFC 3516 `BINARY`
    /// extension), indicating raw 8-bit binary data that may contain NUL octets and is
    /// not MIME content-transfer-encoded.
    ///
    /// When `false` (default), the data is sent using standard literal syntax `{size}`,
    /// indicating the bytes are MIME content-transfer-encoded (e.g., base64 for binary content).
    ///
    /// **Requires server capability:** ``Capability/binary`` (when `true`)
    ///
    /// - SeeAlso: [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516) (BINARY Extension)
    public var withoutContentTransferEncoding: Bool

    /// Creates a new message data descriptor.
    ///
    /// - parameter byteCount: The size of the message in bytes
    /// - parameter withoutContentTransferEncoding: `true` if the bytes are raw 8-bit binary data
    ///   (RFC 3516). Defaults to `false` for MIME content-transfer-encoded data.
    public init(byteCount: Int, withoutContentTransferEncoding: Bool = false) {
        self.byteCount = byteCount
        self.withoutContentTransferEncoding = withoutContentTransferEncoding
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAppendData(_ data: AppendData) -> Int {
        guard case .client(let options) = mode else {
            preconditionFailure("Trying to send command, but not in 'client' mode.")
        }
        switch (options.useNonSynchronizingLiteralPlus, data.withoutContentTransferEncoding) {
        case (true, true):
            return self.writeString("~{\(data.byteCount)+}\r\n")
        case (_, true):
            let size = self.writeString("~{\(data.byteCount)}\r\n")
            self.markStopPoint()
            return size
        case (true, _):
            return self.writeString("{\(data.byteCount)+}\r\n")
        default:
            let size = self.writeString("{\(data.byteCount)}\r\n")
            self.markStopPoint()
            return size
        }
    }
}
