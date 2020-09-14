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
public struct SearchSortModifierSequence: Equatable {

    public var modifierSequenceValue: ModifierSequenceValue

    public init(modifierSequenceValue: ModifierSequenceValue) {
        self.modifierSequenceValue = modifierSequenceValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    
    @discardableResult mutating func writeSearchSortModifierSequence(_ val: SearchSortModifierSequence) -> Int {
        self.writeString("(MODSEQ ") +
            self.writeModifierSequenceValue(val.modifierSequenceValue) +
            self.writeString(")")
    }
    
}
