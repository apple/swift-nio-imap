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

/// Used to instruct the server to only return certain messages that meet given requirements.
public enum FetchModifier: Hashable, Sendable {
    /// Tells the server to respond to a `.fetch` command with messages who's
    /// metadata items have changed since the given reference point.
    case changedSince(ChangedSinceModifier)

    /// Tells the server to only return FETCH results for messages in the specified range.
    ///
    /// Part of https://datatracker.ietf.org/doc/draft-ietf-extra-imap-partial/
    case partial(PartialRange)

    /// Implemented as a catch-all to support modifiers defined in future extensions.
    case other(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchModifier(_ val: FetchModifier) -> Int {
        switch val {
        case .changedSince(let changedSince):
            return self.writeChangedSinceModifier(changedSince)
        case .partial(let range):
            return self.writeString("PARTIAL ") + self.writePartialRange(range)
        case .other(let param):
            return self.writeParameter(param)
        }
    }

    @discardableResult mutating func writeFetchModifiers(_ a: [FetchModifier]) -> Int {
        if a.isEmpty {
            return 0
        }
        return self.writeSpace() +
            self.writeArray(a) { (modifier, self) in
                self.writeFetchModifier(modifier)
            }
    }
}
