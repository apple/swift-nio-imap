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

/// IMAP4 RFC 7162 `mod-sequence-value`
public struct ModificationSequenceValue: Hashable {
    public var value: Int

    public static var zero: Self {
        Self(0)
    }

    public init?(_ value: Int) {
        guard value >= 0 else {
            return nil
        }
        self.value = value
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ModificationSequenceValue: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int

    public init(integerLiteral value: Int) {
        self.value = value
    }
}

// MARK: - CustomStringConvertible

extension ModificationSequenceValue: CustomStringConvertible {
    public var description: String {
        "\(self.value)"
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeModificationSequenceValue(_ value: ModificationSequenceValue) -> Int {
        self.writeString("\(value.value)")
    }
}
