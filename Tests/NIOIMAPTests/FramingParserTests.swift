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
@testable import NIOIMAP
import NIOTestUtils

import XCTest

final class FramingParserTests: XCTestCase {
    
    var parser = ClientFramingParser()
    
    // The parser has a state so we need to recreate with every test
    // as some tests may intentionally have leftovers.
    override func setUp() {
        self.parser = ClientFramingParser()
    }
    
}

extension FramingParserTests {

    func testEmptyBuffer() {
        var buffer: ByteBuffer = ""
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
    }
    
    func testSimpleCommand() {
        var buffer: ByteBuffer = "A1 NOOP\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r\n"])
    }
    
    func testSimpleCommandTimes2() {
        var buffer: ByteBuffer = "A1 NOOP\r\nA2 NOOP\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r\n", "A2 NOOP\r\n"])
    }
    
    // Note that we don't jump the gun when we see a \r, we wait until
    // we've also examined the next byte to see if we should also have
    // consumed a \n.
    func testDripfeeding() {
        var buffer: ByteBuffer = "A"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "1"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = " "
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "N"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "O"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "O"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "P"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "\r"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 NOOP\r\n"])
    }
    
    // Note this isn't strictly a valid login command, but it doesn't matter.
    // Rememeber that the framing parser is just there to look for frames.
    func testParsingLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {3}\r\nhey\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3}\r\n", "hey", "\r\n"])
    }
    
    func testParsingBinaryLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {~3}\r\nhey\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {~3}\r\n", "hey", "\r\n"])
    }
    
    func testParsingLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {3+}\r\nhey\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3+}\r\n", "hey", "\r\n"])
    }
    
    func testParsingLiteralMinus() {
        var buffer: ByteBuffer = "A1 LOGIN {3-}\r\nhey\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3-}\r\n", "hey", "\r\n"])
    }
    
    func testParsingBinaryLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {~3+}\r\nhey\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {~3+}\r\n", "hey", "\r\n"])
    }
    
    // full command "A1 LOGIN {3}\r\n123 test\r\n
    func testDripfeedingLiteral() {
        var buffer: ByteBuffer = "A1 LOGIN {3"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "}"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "\r"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3}\r\n"])
        
        buffer = "1"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["1"])
        
        buffer = "2"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["2"])
        
        buffer = "3"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["3"])
        
        buffer = " test\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [" test\r\n"])
    }
    
    func testDripfeedingLiteralPlus() {
        var buffer: ByteBuffer = "A1 LOGIN {3+"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "1"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "}"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "\r"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [])
        
        buffer = "\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["A1 LOGIN {3+}\r\n"])
        
        buffer = "1"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["1"])
        
        buffer = "2"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["2"])
        
        buffer = "3"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), ["3"])
        
        buffer = " test\r\n"
        XCTAssertEqual(self.parser.appendAndFrameBuffer(&buffer), [" test\r\n"])
    }
}
