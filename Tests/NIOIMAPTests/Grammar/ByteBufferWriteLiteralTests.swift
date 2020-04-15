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

import XCTest
import NIO
@testable import IMAPCore
@testable import NIOIMAP

class ByteBufferWriteLiteralTests: EncodeTestClass {

}

// MARK: writeIMAPString
extension ByteBufferWriteLiteralTests {
    
    func testWriteIMAPString() {
        
        let inputs: [(ByteBuffer, String, UInt)] = [
            ("", "\"\"", #line),
            ("abc", #""abc""#, #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\""), count: 1)), "{1}\r\n\"", #line),
            (ByteBuffer(ByteBufferView(repeating: UInt8(ascii: "\\"), count: 1)), "{1}\r\n\\", #line),
            ("\\\"", "{2}\r\n\\\"", #line),
            ("a", "\"a\"", #line),
            ("\0", "~{1}\r\n\0", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.self.testBuffer.clear()
            let size = self.self.testBuffer.writeIMAPString(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
        
    }
    
}

// MARK: writeLiteral
extension ByteBufferWriteLiteralTests {
    
    func testWriteLiteral() {
        
        let inputs: [(ByteBuffer, String, UInt)] = [
            ("", "{0}\r\n", #line),
            ("abc", "{3}\r\nabc", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeLiteral(Array(test.readableBytesView))
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
        
    }
    
}

// MARK: writeLiteral8
extension ByteBufferWriteLiteralTests {

    func testWriteLiteral8() {
        
        let inputs: [(ByteBuffer, String, UInt)] = [
            ("", "~{0}\r\n", #line),
            ("abc", "~{3}\r\nabc", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeLiteral8(Array(test.readableBytesView))
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
        
    }

}
