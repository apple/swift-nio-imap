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

/// Unique Message Identifier
///
/// Note that valid `UID`s are 1 ... 4294967295 (UInt32.max).
/// The maximum value is often rendered as `*` when encoded.
///
/// See RFC 3501 section 2.3.1.1.
public struct UID: MessageIdentifier, Sendable {
    public var rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
}

/// See `MessageIdentifierRange<UID>`
public typealias UIDRange = MessageIdentifierRange<UID>

/// See `MessageIdentifierSet<UID>`
public typealias UIDSet = MessageIdentifierSet<UID>

/// See `MessageIdentifierSetNonEmpty<UID>`
public typealias UIDSetNonEmpty = MessageIdentifierSetNonEmpty<UID>

// MARK: - Conversion

extension UID {
    public init(_ other: UnknownMessageIdentifier) {
        self.init(rawValue: other.rawValue)
    }
}

extension UnknownMessageIdentifier {
    public init(_ other: UID) {
        self.init(rawValue: other.rawValue)
    }
}
