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
public struct SearchSortModificationSequence: Equatable {
    public var modifierSequenceValue: ModificationSequenceValue

    public init(modifierSequenceValue: ModificationSequenceValue) {
        self.modifierSequenceValue = modifierSequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchSortModificationSequence(_ val: SearchSortModificationSequence) -> Int {
        self.writeString("(MODSEQ ") +
            self.writeModificationSequenceValue(val.modifierSequenceValue) +
            self.writeString(")")
    }
}
