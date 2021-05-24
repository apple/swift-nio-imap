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

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedExtensionComp(_ comp: [String]) -> Int {
        self.write(if: comp.count >= 1) {
            self.writeArray(comp) { (string, self) in
                self.writeIMAPString(string)
            }
        }
    }
}
