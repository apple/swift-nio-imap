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

/// The unique identifier validity value of a mailbox. Combined with a message UID to form a 64-bit identifier.
public struct UIDValidity: RawRepresentable, Hashable {
    
    /// The underlying raw value.
    public var rawValue: UInt32
    
    /// Creates a new UIDValidity from an integer, after first checking that the given `Int` can fit
    /// within a `UInt32`.
    /// - parameter rawValue: The value to use.
    /// - returns: `nil` if the given value cannot fit inside a `UInt32`, otherwise a new `UIDValidity`.
    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = UInt32(rawValue)
    }

    /// Creates a new UIDValidity from a `UInt32`, after first checking that the given value `> 0`
    /// - parameter rawValue: The value to use.
    /// - returns: `nil` if the given value is `0`, otherwise a new `UIDValidity`.
    public init?(rawValue: UInt32) {
        guard rawValue >= 1 else { return nil }
        self.rawValue = rawValue
    }
}

// MARK: - Integer literal

extension UIDValidity: ExpressibleByIntegerLiteral {
    
    /// Creates a `UIDValidity` from some integer literal value.
    /// - parameter value: The literal value.
    public init(integerLiteral value: UInt32) {
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
        assert(value >= 1, "UIDValidity cannot be 0")
        self.init(rawValue: Int(value))!
    }
}

extension UIDValidity {
    
    /// Creates a `UIDValidity` from some `BinaryInteger` after checking
    /// that the given value fits within a `UInt32`.
    /// - parameter source: Some `BinaryInteger`.
    /// - returns: `nil` if the given value cannot fit within a `UInt32`, otherwise a new `UIDValidity`.
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard let rawValue = UInt32(exactly: source) else { return nil }
        self.init(rawValue: rawValue)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDValidity(_ data: UIDValidity) -> Int {
        self.writeString("\(data.rawValue)")
    }
}
