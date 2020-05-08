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

/// IMAPv4 `tagged-ext-val`
public enum TaggedExtensionValue: Equatable {
    case simple(TaggedExtensionSimple)
    case comp([String])
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeTaggedExtensionValue(_ value: TaggedExtensionValue) -> Int {
        switch value {
        case .simple(let simple):
            return self.writeTaggedExtensionSimple(simple)
        case .comp(let comp):
            return
                self.writeString("(") +
                self.writeTaggedExtensionComp(comp) +
                self.writeString(")")
        }
    }
}
