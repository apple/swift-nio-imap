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

/// A byte range specifying an offset and optional length within a message or section.
///
/// Byte ranges are used with `PARTIAL` fetch modifiers (RFC 9394) to retrieve only a portion of
/// message data without downloading the entire body. They may be applied to IMAP URLs (RFC 5092)
/// for authenticated partial access.
///
/// The offset specifies the starting byte position, and the length (if present) specifies how many
/// bytes to include. If length is nil, the range extends to the end of the data.
///
/// - SeeAlso: [RFC 5092 IMAP URL Scheme](https://datatracker.ietf.org/doc/html/rfc5092)
/// - SeeAlso: [RFC 9394 IMAP PARTIAL Extension](https://datatracker.ietf.org/doc/html/rfc9394)
public struct ByteRange: Hashable, Sendable {
    /// The offset in bytes from the beginning of the message/data in question.
    public var offset: Int

    /// The number of bytes the range covers.
    public var length: Int?

    /// Creates a new ``ByteRange``
    /// - parameter offset: The offset in bytes from the beginning of the message/data in question.
    /// - parameter length: The number of bytes the range covers.
    public init(offset: Int, length: Int?) {
        self.offset = offset
        self.length = length
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeByteRange(_ num: ClosedRange<UInt32>) -> Int {
        self.writeString("<\(num.lowerBound).\(num.count)>")
    }

    @discardableResult mutating func writeByteRange(_ data: ByteRange) -> Int {
        self.writeString("\(data.offset)")
            + self.writeIfExists(data.length) { length in
                self.writeString(".\(length)")
            }
    }
}
