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

/// RFC 5092 IMAP URL
public struct UIDValidity: RawRepresentable, Hashable {
    public var rawValue: UInt32
    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = UInt32(rawValue)
    }

    public init?(rawValue: UInt32) {
        guard rawValue >= 1 else { return nil }
        self.rawValue = rawValue
    }
}

// MARK: - Integer literal

extension UIDValidity: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }

    /// Create a `UIDValidity`, asserting with invalid values.
    /// - parameter value: An integer value that must be a non-zero `UInt32` value.
    public init(_ value: Int) {
        assert(value <= UInt32.max, "UIDValidity must be a UInt32")
        self.init(UInt32(value))
    }

    /// Create a `UIDValidity`, asserting with invalid values.
    /// - parameter value: A `UInt32` that must be non-zero.
    public init(_ value: UInt32) {
        assert(value >= 0, "UIDValidity cannot be 0")
        self.init(rawValue: Int(value))!
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDValidaty(_ data: UIDValidity) -> Int {
        self.writeString(";UIDVALIDITY=\(data.rawValue)")
    }
}
