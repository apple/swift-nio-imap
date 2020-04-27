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

extension NIOIMAP {
    /// IMAPv4 `status-att-val`
    public enum StatusAttributeValue: Equatable {
        case messages(Int)
        case uidNext(Int)
        case uidValidity(Int)
        case unseen(Int)
        case deleted(Int)
        case size(Int)
        case modSequence(ModifierSequenceValue)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeStatusOption(_ option: [NIOIMAP.StatusAttribute]) -> Int {
        self.writeString("STATUS ") +
            self.writeArray(option) { (att, self) in
                self.writeStatusAttribute(att)
            }
    }

    @discardableResult mutating func writeStatusAttributeList(_ list: [NIOIMAP.StatusAttributeValue]) -> Int {
        self.writeArray(list, parenthesis: false) { (val, self) in
            self.writeStatusAttributeValue(val)
        }
    }

    @discardableResult mutating func writeStatusAttributeValue(_ val: NIOIMAP.StatusAttributeValue) -> Int {
        switch val {
        case .messages(let num):
            return self.writeString("MESSAGES \(num)")
        case .uidNext(let num):
            return self.writeString("UIDNEXT \(num)")
        case .uidValidity(let num):
            return self.writeString("UIDVALIDITY \(num)")
        case .unseen(let num):
            return self.writeString("UNSEEN \(num)")
        case .deleted(let num):
            return self.writeString("DELETED \(num)")
        case .size(let num):
            return self.writeString("SIZE \(num)")
        case .modSequence(let value):
            return
                self.writeString("HIGHESTMODSEQ ") +
                self.writeModifierSequenceValue(value)
        }
    }
}
