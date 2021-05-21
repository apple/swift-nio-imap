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

@testable import NIOIMAPCore
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
        let test1 = "hello, world"
        XCTAssertEqual(String(validatingUTF8Bytes: test1.utf8), test1)

        let test2: [UInt8] = [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4]
        XCTAssertEqual(String(validatingUTF8Bytes: test2), "⚡⚢⚣⚤")
    }
}

extension String_ByteBuffer_Tests {
    
    func testInitBestEffortDecodingValid() {
        let test1 = "hello, world"
        XCTAssertEqual(String(bestEffortDecodingUTF8Bytes: test1.utf8), test1)

        let test2: [UInt8] = [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4]
        XCTAssertEqual(String(bestEffortDecodingUTF8Bytes: test2), "⚡⚢⚣⚤")
    }
    
    func testInitBestEffortDecodingInvalid() {
        let test2: [UInt8] = [0x41, 0xff, 0x42]
        XCTAssertEqual(String(bestEffortDecodingUTF8Bytes: test2), "AB")
    }
    
}
