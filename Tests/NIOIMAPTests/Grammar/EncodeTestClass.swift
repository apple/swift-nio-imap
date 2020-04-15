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
import XCTest
@testable import IMAPCore

class EncodeTestClass: XCTestCase {

    var testBuffer = ByteBufferAllocator().buffer(capacity: 1)

    var testBufferString: String {
        return String(decoding: self.testBuffer.readableBytesView, as: Unicode.UTF8.self)
    }

    override func setUp() {
        testBuffer = ByteBufferAllocator().buffer(capacity: 1)
    }

}
