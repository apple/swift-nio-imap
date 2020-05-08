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

public struct StoreModifier: Equatable {
    public var name: String
    public var parameters: TaggedExtensionValue?

    public static func name(_ name: String, parameters: TaggedExtensionValue?) -> Self {
        Self(name: name, parameters: parameters)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeStoreModifier(_ modifier: StoreModifier) -> Int {
        self.writeStoreModifierName(modifier.name) +
            self.writeIfExists(modifier.parameters) { (params) -> Int in
                self.writeSpace() +
                    self.writeTaggedExtensionValue(params)
            }
    }

    @discardableResult mutating func writeStoreModifiers(_ modifiers: [StoreModifier]) -> Int {
        self.writeSpace() +
            self.writeArray(modifiers) { (modifier, self) -> Int in
                self.writeStoreModifier(modifier)
            }
    }
}
