//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Represents the identifier of a message stored on a server.
public struct MessageID: Hashable, RawRepresentable {
    /// The `String` message identifier.
    public var rawValue: String

    /// Creates a new `MessageID` from the given string.
    /// - rawValue: The `String` message identifier.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - ExpressibleByStringLiteral

extension MessageID: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMessageID(_ id: MessageID) -> Int {
        self.writeIMAPString(id.rawValue)
    }
}
