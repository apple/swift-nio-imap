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

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceRange(_ range: SequenceRange) -> Int {
        self.writeSequenceNumberOrWildcard(range.range.lowerBound)
            + self.write(if: range.range.lowerBound < range.range.upperBound) {
                self.writeString(":") + self.writeSequenceNumberOrWildcard(range.range.upperBound)
            }
    }
}
