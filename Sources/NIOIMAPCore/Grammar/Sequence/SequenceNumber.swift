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

/// Message Sequence Number
///
/// See RFC 3501 section 2.3.1.2.
///
/// IMAPv4 `seq-number`
public struct SequenceNumber: MessageIdentifier, Sendable {
    /// The raw value of the sequence number, defined in RFC 3501 to be an unsigned 32-bit integer.
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

/// See `MessageIdentifierRange<SequenceNumber>`
public typealias SequenceRange = MessageIdentifierRange<SequenceNumber>

/// See `MessageIdentifierSet<SequenceNumber>`
public typealias SequenceSet = MessageIdentifierSet<SequenceNumber>

// MARK: - Conversion

extension SequenceNumber {
    public init(_ other: UnknownMessageIdentifier) {
        self.init(rawValue: other.rawValue)
    }
}

extension UnknownMessageIdentifier {
    public init(_ other: SequenceNumber) {
        self.init(rawValue: other.rawValue)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSequenceNumber(_ num: SequenceNumber) -> Int {
        self.writeString("\(num.rawValue)")
    }

    @discardableResult mutating func writeSequenceNumberOrWildcard(_ num: SequenceNumber) -> Int {
        if num.rawValue == UInt32.max {
            return self.writeString("*")
        } else {
            return self.writeString("\(num.rawValue)")
        }
    }
}
