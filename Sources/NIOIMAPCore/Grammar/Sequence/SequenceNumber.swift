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

/// IMAPv4 `seq-number`
public enum SequenceNumber: Equatable {
    case last // i.e. last (according to IMAPv4)
    case number(Int)
}

// MARK: - Integer literal

extension SequenceNumber: ExpressibleByIntegerLiteral {
    public typealias IntegerLiteralType = Int

    public init(integerLiteral value: Self.IntegerLiteralType) {
        self = .number(value)
    }
}

// MARK: - Comparable

extension SequenceNumber: Comparable {
    // last is treated as the largest possible element
    // i..e if the greatest mail ID is 5, then last is 5
    public static func < (lhs: SequenceNumber, rhs: SequenceNumber) -> Bool {
        switch (lhs, rhs) {
        case (.last, .last):
            return false
        case (.last, .number(_)):
            return false
        case (.number(_), .last):
            return true
        case (.number(let num1), .number(let num2)):
            return num1 < num2
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeSequenceNumber(_ num: SequenceNumber) -> Int {
        switch num {
        case .last:
            return self.writeString("*")
        case .number(let num):
            return self.writeString("\(num)")
        }
    }
}
