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
}
