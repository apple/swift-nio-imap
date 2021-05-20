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

import NIOIMAPCore
import XCTest

class String_ByteBuffer_Tests: XCTestCase {}

extension String_ByteBuffer_Tests {
    func testInitValidatingUTF8Overflow() {
        let bytes: [UInt8] = [0, 1, 2, 3, 255]
        XCTAssertNil(String(validatingUTF8Bytes: bytes))
    }

    func testInitValidatingUTF8Invalid() {
        let test1: [UInt8] = [0xC2]
        XCTAssertNil(String(validatingUTF8Bytes: test1))

        let test2: [UInt8] = [0xE1, 0x80]
        XCTAssertNil(String(validatingUTF8Bytes: test2))
    }

    func testInitValidatingUTF8Valid() {
        let test = "hello, world".utf8
        XCTAssertEqual(String(validatingUTF8Bytes: test), "hello, world")
    }
}
