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

extension EncodeBuffer {
    mutating func writeAtom(_ str: String) -> Int {
        self.writeString(str)
    }

    mutating func writeAString(_ str: String) -> Int {
        // allSatisfy vs contains because IMO it's a little clearer
        var foundNull = false
        let canUseAtom = str.utf8.allSatisfy { c in
            foundNull = foundNull || (c == 0)
            return c.isAtomChar && !foundNull
        }

        if canUseAtom {
            return self.writeString(str)
        } else {
            return self.writeIMAPString(str)
        }
    }
}
