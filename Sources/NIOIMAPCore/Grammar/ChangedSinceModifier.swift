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
    public var modifiedSequence: ModifierSequenceValue

    public init(modifiedSequence: ModifierSequenceValue) {
        self.modifiedSequence = modifiedSequence
    }
}

/// RFC 7162
public struct UnchangedSinceModifier: Equatable {
    public var modifiedSequence: ModifierSequenceValue

    public init(modifiedSequence: ModifierSequenceValue) {
        self.modifiedSequence = modifiedSequence
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeChangedSinceModifier(_ val: ChangedSinceModifier) -> Int {
        self.writeString("CHANGEDSINCE ") + self.writeModifierSequenceValue(val.modifiedSequence)
    }

    @discardableResult mutating func writeUnchangedSinceModifier(_ val: UnchangedSinceModifier) -> Int {
        self.writeString("UNCHANGEDSINCE ") + self.writeModifierSequenceValue(val.modifiedSequence)
    }
}
