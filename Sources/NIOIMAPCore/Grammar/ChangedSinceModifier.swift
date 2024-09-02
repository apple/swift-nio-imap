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

/// Used in a fetch command to fetch data for all messages that have metadata
/// items changed since some known modification sequence.
public struct ChangedSinceModifier: Hashable, Sendable {
    /// The known modification sequence to use as a reference date.
    public var modificationSequence: ModificationSequenceValue

    /// Creates a new `ChangedSinceModifier` by wrapping a `ModificationSequenceValue`
    /// - parameter modificationSequence: The known modification sequence to use as a reference date.
    public init(modificationSequence: ModificationSequenceValue) {
        self.modificationSequence = modificationSequence
    }
}

/// Used in a fetch command to fetch data for all messages that have not had
/// metadata items changed since some known modification sequence.
public struct UnchangedSinceModifier: Hashable, Sendable {
    /// The known modification sequence to use as a reference date.
    public var modificationSequence: ModificationSequenceValue

    /// Creates a new `UnchangedSinceModifier` by wrapping a `ModificationSequenceValue`
    /// - parameter modificationSequence: The known modification sequence to use as a reference date.
    public init(modificationSequence: ModificationSequenceValue) {
        self.modificationSequence = modificationSequence
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeChangedSinceModifier(_ val: ChangedSinceModifier) -> Int {
        self.writeString("CHANGEDSINCE ") + self.writeModificationSequenceValue(val.modificationSequence)
    }

    @discardableResult mutating func writeUnchangedSinceModifier(_ val: UnchangedSinceModifier) -> Int {
        self.writeString("UNCHANGEDSINCE ") + self.writeModificationSequenceValue(val.modificationSequence)
    }
}
