//
//  String+ByteBuffer+Tests.swift
//  CLILibTests
//
//  Created by David Evans on 20/05/2021.
//

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
