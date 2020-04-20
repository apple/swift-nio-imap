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

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writePatterns(_ patterns: [ByteBuffer]) -> Int {
        self.writeArray(patterns) { (pattern, self) in
            self.writeIMAPString(pattern)
        }
    }

}
