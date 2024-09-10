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
///
/// This is the “full” Message-ID, including the angled brackets, e.g.
/// `<B27397-0100000@cac.washington.edu>`.
///
/// See RFC 2822 section 3.6.4.
public struct MessageID: Hashable, Sendable {
    /// The `String` message identifier.
    var rawValue: String

    /// Creates a new `MessageID` from the given string.
    /// - rawValue: The `String` message identifier.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

extension String {
    public init(_ id: MessageID) {
        self = id.rawValue
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
