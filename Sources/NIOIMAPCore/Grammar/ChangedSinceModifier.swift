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

/// RFC 7162
public struct ChangedSinceModifier: Equatable {
    public var modificationSequence: ModificationSequenceValue

    public init(modificationSequence: ModificationSequenceValue) {
        self.modificationSequence = modificationSequence
    }
}

/// RFC 7162
public struct UnchangedSinceModifier: Equatable {
    public var modificationSequence: ModificationSequenceValue

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
