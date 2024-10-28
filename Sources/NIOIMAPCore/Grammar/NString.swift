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

// MARK: - IMAP

extension EncodeBuffer {
    @discardableResult mutating func writeNString(_ string: ByteBuffer?) -> Int {
        guard let string = string else {
            return self.writeNil()
        }
        return self.writeIMAPString(string)
    }

    @discardableResult mutating func writeNString(_ string: String?) -> Int {
        guard let string = string else {
            return self.writeNil()
        }
        return self.writeIMAPString(string)
    }
}
