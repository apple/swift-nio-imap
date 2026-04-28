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

extension MessagePath {
    /// A byte range suffix for partial IMAP URL fetches.
    ///
    /// Wraps a ``/NIOIMAPCore/ByteRange`` for use in IMAP URLs with the `/;PARTIAL=` encoding
    /// (RFC 5092). It enables clients to request only a portion of a message via URL without
    /// downloading the entire body.
    ///
    /// - SeeAlso: [RFC 5092 IMAP URL Scheme](https://datatracker.ietf.org/doc/html/rfc5092)
    public struct ByteRange: Hashable, Sendable {
        /// The underlying ``/NIOIMAPCore/ByteRange``.
        public var range: NIOIMAPCore.ByteRange

        /// Creates a new `MessagePath.ByteRange`.
        /// - parameter range: The ``/NIOIMAPCore/ByteRange`` to be wrapped.
        public init(range: NIOIMAPCore.ByteRange) {
            self.range = range
        }
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessagePathByteRange(_ data: MessagePath.ByteRange) -> Int {
        self.writeString("/;PARTIAL=") + self.writeByteRange(data.range)
    }

    @discardableResult mutating func writeMessagePathByteRangeOnly(_ data: MessagePath.ByteRange) -> Int {
        self.writeString(";PARTIAL=") + self.writeByteRange(data.range)
    }
}
