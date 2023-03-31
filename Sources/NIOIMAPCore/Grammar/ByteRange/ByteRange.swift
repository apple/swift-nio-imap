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

/// Represents a range of bytes in a larger whole. See RFC 5092
public struct ByteRange: Hashable {
    /// The offset in bytes from the beginning of the message/data in question.
    public var offset: Int

    /// The number of bytes the range covers.
    public var length: Int?

    /// Creates a new `PartialRange`
    /// - parameter offset: The offset in bytes from the beginning of the message/data in question.
    /// - parameter length: The number of bytes the range covers.
    public init(offset: Int, length: Int?) {
        self.offset = offset
        self.length = length
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writePartial(_ num: ClosedRange<UInt32>) -> Int {
        self.writeString("<\(num.lowerBound).\(num.count)>")
    }

    @discardableResult mutating func writePartialRange(_ data: ByteRange) -> Int {
        self.writeString("\(data.offset)") +
            self.writeIfExists(data.length) { length in
                self.writeString(".\(length)")
            }
    }
}
