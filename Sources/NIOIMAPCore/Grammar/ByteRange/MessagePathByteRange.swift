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
    /// Used to append a `ByteRange` as part of a URL.
    public struct ByteRange: Hashable, Sendable {
        /// The `PartialRange` to append.
        public var range: NIOIMAPCore.ByteRange

        /// Creates a new `MessagePath.ByteRange`.
        /// - parameter range: The `PartialRange` to append.
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
