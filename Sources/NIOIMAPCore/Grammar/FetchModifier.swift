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
public enum FetchModifier: Hashable {
    /// Tells the server to respond to a `.fetch` command with messages who's
    /// metadata items have changed since the given reference point.
    case changedSince(ChangedSinceModifier)

    /// Implemented as a catch-all to support modifiers defined in future extensions.
    case other(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeFetchModifier(_ val: FetchModifier) -> Int {
        switch val {
        case .changedSince(let changedSince):
            return self.writeChangedSinceModifier(changedSince)
        case .other(let param):
            return self.writeParameter(param)
        }
    }

    @discardableResult mutating func writeFetchModifiers(_ a: [FetchModifier]) -> Int {
        self.writeString(" (") +
            self.writeArray(a) { (modifier, self) in
                self.writeFetchModifier(modifier)
            } +
            self.writeString(")")
    }
}
