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

/// Sent as a response to a `.sort` command.
public struct SortData: Equatable {
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
        self.writeString("SORT") +
            self.writeIfExists(data) { (data) -> Int in
                self.writeArray(data.identifiers, prefix: " ", parenthesis: false) { (element, buffer) -> Int in
                    buffer.writeString("\(element)")
                } +
                    self.writeSpace() +
                    self.writeString("(MODSEQ ") +
                    self.writeModificationSequenceValue(data.modificationSequence) +
                    self.writeString(")")
            }
    }
}
