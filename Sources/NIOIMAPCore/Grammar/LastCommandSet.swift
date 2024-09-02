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
/// a concrete set type.
public enum LastCommandSet<N: MessageIdentifier>: Hashable, Sendable {
    /// A specific set that will be sent to the IMAP server. E.g. `1, 2:5, 10:*`
    case set(MessageIdentifierSetNonEmpty<N>)

    /// Tells the server to use the result of the last command, described in RFC 5182.
    case lastCommand
}

extension LastCommandSet {
    public static func range(_ range: MessageIdentifierRange<N>) -> Self {
        .set(MessageIdentifierSetNonEmpty(range: range))
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeLastCommandSet<T>(_ set: LastCommandSet<T>) -> Int {
        switch set {
        case .lastCommand:
            return self.writeString("$")
        case .set(let set):
            return set.writeIntoBuffer(&self)
        }
    }
}
