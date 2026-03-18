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

/// Response data from a `SORT` command, including optional modification sequence.
///
/// The `SORT` extension (RFC 5256) allows clients to request server-side sorting of messages by various
/// criteria. The server responds with message sequence numbers in sorted order. When combined with
/// the `CONDSTORE` extension (RFC 7162), the response also includes the highest modification sequence
/// for all returned messages to aid efficient resynchronization.
///
/// ### Example
///
/// ```
/// C: A001 SORT (ARRIVAL) ALL
/// S: * SORT 3 2 1
/// S: A001 OK SORT completed
/// ```
///
/// This response indicates messages 3, 2, and 1 are the result in sorted order (most recent arrival first).
///
/// - SeeAlso: [RFC 5256 SORT Extension](https://datatracker.ietf.org/doc/html/rfc5256)
/// - SeeAlso: [RFC 7162 CONDSTORE MODSEQ](https://datatracker.ietf.org/doc/html/rfc7162)
public struct SortData: Hashable, Sendable {
    /// Message sequence numbers that match the search.
    public var identifiers: [Int]

    /// The highest mod-sequence for all messages being returned.
    public var modificationSequence: ModificationSequenceValue

    /// Creates a new `SortData`.
    /// - parameter identifiers: Message sequence numbers that match the search.
    /// - parameter modificationSequence: The highest mod-sequence for all messages being returned.
    public init(identifiers: [Int], modificationSequence: ModificationSequenceValue) {
        self.identifiers = identifiers
        self.modificationSequence = modificationSequence
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSortData(_ data: SortData?) -> Int {
        self.writeString("SORT")
            + self.writeIfExists(data) { (data) -> Int in
                self.writeArray(data.identifiers, prefix: " ", parenthesis: false) { (element, buffer) -> Int in
                    buffer.writeString("\(element)")
                } + self.writeSpace() + self.writeString("(MODSEQ ")
                    + self.writeModificationSequenceValue(data.modificationSequence) + self.writeString(")")
            }
    }
}
