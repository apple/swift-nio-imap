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
public struct UIDValidity: Hashable {
    /// The underlying raw value.
    let rawValue: UInt32

    /// Creates a `UIDValidity` from some `BinaryInteger` after checking
    /// that the given value fits within a `UInt32`.
    /// - parameter source: Some `BinaryInteger`.
    /// - returns: `nil` if the given value cannot fit within a `UInt32`, otherwise a new `UIDValidity`.
    public init?<T>(exactly source: T) where T: BinaryInteger {
        guard source > 0, let rawValue = UInt32(exactly: source) else { return nil }
        self.rawValue = rawValue
    }
}

// MARK: - Integer literal

extension UIDValidity: ExpressibleByIntegerLiteral {
    /// Creates a `UIDValidity` from some integer literal value.
    /// - parameter value: The literal value.
    public init(integerLiteral value: UInt32) {
        self.init(exactly: value)!
    }
}

// MARK: - Binary Integer
extension BinaryInteger {
    
    public init(_ value: UIDValidity) {
        self = Self(value.rawValue)
    }
    
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDValidity(_ data: UIDValidity) -> Int {
        self.writeString("\(data.rawValue)")
    }
}
