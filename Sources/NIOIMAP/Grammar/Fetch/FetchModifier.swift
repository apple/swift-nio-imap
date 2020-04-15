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
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {
    
    @discardableResult mutating func writeFetchModifiers(_ array: [IMAPCore.FetchModifier]) -> Int {
        guard array.count > 0 else {
            return 0
        }
        
        return
            self.writeSpace() +
            self.writeArray(array) { (param, self) -> Int in
                self.writeFetchModifier(param)
            }
    }
    
    @discardableResult mutating func writeFetchModifier(_ param: IMAPCore.FetchModifier) -> Int {
        self.writeFetchModifierName(param.name) +
        self.writeIfExists(param.value) { (value) -> Int in
            self.writeSpace() +
            self.writeTaggedExtensionValue(value)
        }
    }
    
}
