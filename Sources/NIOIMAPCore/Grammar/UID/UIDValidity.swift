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
    public var rawValue: Int
    public init?(rawValue: Int) {
        guard rawValue >= 1, rawValue <= UInt32.max else { return nil }
        self.rawValue = rawValue
    }
}

// MARK: - Integer literal

extension UIDValidity: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(rawValue: value)!
    }

    public init(_ value: Int) {
        self.init(rawValue: value)!
    }

    public init(_ value: UInt32) {
        self.rawValue = Int(value)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeUIDValidaty(_ data: UIDValidity) -> Int {
        self.writeString(";UIDVALIDITY=\(data.rawValue)")
    }
}
