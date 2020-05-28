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

protocol Parser {
    var bufferLimit: Int { get }
}

extension Parser {
    func throwIfExceededBufferLimit(_ buffer: inout ByteBuffer) throws {
        // try to find LF in the first `self.bufferLimit` bytes
        guard buffer.readableBytesView.prefix(self.bufferLimit).contains(UInt8(ascii: "\n")) else {
            // We're in line-parsing mode and there's no newline, let's buffer more. But let's do a quick check
            // that don't buffer too much.
            guard buffer.readableBytes <= self.bufferLimit else {
                // We're in line parsing mode
                throw ParsingError.lineTooLong
            }
            throw _IncompleteMessage()
        }
    }
}
