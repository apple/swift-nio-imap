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

import struct NIO.ByteBuffer

/// RFC 7162
public struct SortData: Equatable {
    
    public var identifiers: [Int]
    
    public var modifierSequence: SearchSortModifierSequence
    
    public init(identifiers: [Int], modifierSequence: SearchSortModifierSequence) {
        self.identifiers = identifiers
        self.modifierSequence = modifierSequence
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    
    @discardableResult mutating func writeSortData(_ data: SortData?) -> Int {
        self.writeString("SORT") +
            self.writeIfExists(data, callback: { (data) -> Int in
                self.writeArray(data.identifiers, separator: "", parenthesis: false) { (element, buffer) -> Int in
                    buffer.writeSpace() +
                    buffer.writeString("\(element)")
                } +
                self.writeSpace() +
                self.writeSearchSortModifierSequence(data.modifierSequence)
            })
    }
    
}
