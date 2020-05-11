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

/// IMAPv4 `search-ret-opt-ext`
public struct SearchReturnOptionExtension: Equatable {
    public var modifierName: String
    public var params: TaggedExtensionValue?

    public init(modifierName: String, params: TaggedExtensionValue? = nil) {
        self.modifierName = modifierName
        self.params = params
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeSearchReturnOptionExtension(_ option: SearchReturnOptionExtension) -> Int {
        self.writeTaggedExtensionLabel(option.modifierName) +
            self.writeIfExists(option.params) { (params) -> Int in
                self.writeSpace() +
                    self.writeTaggedExtensionValue(params)
            }
    }
}
