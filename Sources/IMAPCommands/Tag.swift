//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

extension IMAPConnection {
    /// A command tag that uniquely identifies an in-flight IMAP command.
    public struct Tag: Hashable, Sendable {
        var rawValue: UInt64
    }
}

extension IMAPConnection.Tag: CustomStringConvertible {
    public var description: String { String(self) }
}

extension IMAPConnection.Tag {
    /// The first tag in a sequence.
    public static let first = IMAPConnection.Tag(rawValue: 1)

    /// Returns the next tag in the sequence.
    public func makeNext() -> IMAPConnection.Tag {
        IMAPConnection.Tag(rawValue: self.rawValue &+ 1)
    }
}

extension IMAPConnection.Tag: Encodable {}

extension String {
    public init(_ tag: IMAPConnection.Tag) {
        self = "A\(tag.rawValue)"
    }
}

extension IMAPConnection.Tag {
    public init?(_ text: String) {
        guard
            text.count < 25,
            text.allSatisfy({ $0.isASCII }),
            text.first == "A"
        else { return nil }
        let remainder = text[text.index(after: text.startIndex)...]
        guard
            remainder.allSatisfy({
                guard
                    let v = $0.asciiValue,
                    0x30 <= v,
                    v <= 0x39
                else { return false }
                return true
            }),
            let value = UInt64(remainder)
        else { return nil }
        self.init(rawValue: value)
    }
}
