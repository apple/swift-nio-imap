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
import NIOIMAPCore
import XCTest

class EncodeTestClass: XCTestCase {
    var testBuffer = EncodeBuffer(ByteBufferAllocator().buffer(capacity: 128), mode: .server)

    var testBufferString: String {
        var remaining = self.testBuffer
        let nextBit = remaining.nextChunk().bytes
        return String(buffer: nextBit)
    }

    override func setUp() {
        self.testBuffer = EncodeBuffer(ByteBufferAllocator().buffer(capacity: 128), mode: .server)
    }
}
