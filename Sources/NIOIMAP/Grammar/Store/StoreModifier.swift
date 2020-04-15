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

import NIO

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeStoreModifier(_ modifier: NIOIMAP.StoreModifier) -> Int {
        self.writeStoreModifierName(modifier.name) +
        self.writeIfExists(modifier.parameters) { (params) -> Int in
            self.writeSpace() +
            self.writeTaggedExtensionValue(params)
        }
    }
    
    @discardableResult mutating func writeStoreModifiers(_ modifiers: [NIOIMAP.StoreModifier]) -> Int {
        self.writeSpace() +
        self.writeArray(modifiers) { (modifier, self) -> Int in
            self.writeStoreModifier(modifier)
        }
    }
    
}
