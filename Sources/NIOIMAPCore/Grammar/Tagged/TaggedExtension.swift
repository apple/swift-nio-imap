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

public struct TaggedExtension: Equatable {
    public var label: String
    public var value: TaggedExtensionValue

    public init(label: String, value: TaggedExtensionValue) {
        self.label = label
        self.value = value
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeTaggedExtension(_ ext: TaggedExtension) -> Int {
        self.writeTaggedExtensionLabel(ext.label) +
            self.writeSpace() +
            self.writeTaggedExtensionValue(ext.value)
    }
}
