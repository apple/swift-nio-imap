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

/// Provides support for using either the result of the last command (`.lastCommand`) or
/// a concrete message identifier (UID or message sequence number).
public enum LastCommandMessageID<N: MessageIdentifier>: Hashable {
    /// A specific message identifier, e.g. the UID 54011.
    case id(N)

    /// `$`: Tells the server to use the result of the last command, described in RFC 5182.
    case lastCommand
}

extension LastCommandMessageID: Sendable where N: Sendable {}

extension EncodeBuffer {
    @discardableResult mutating func writeLastCommandMessageID<T>(_ set: LastCommandMessageID<T>) -> Int {
        switch set {
        case .lastCommand:
            return self.writeString("$")
        case .id(let num):
            return writeMessageIdentifier(num)
        }
    }
}
