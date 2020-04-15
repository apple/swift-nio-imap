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

class CommandParser_Tests: XCTest {
    
}

// MARK: - init
extension CommandParser_Tests {
    
    func testInit_defaultBufferSize() {
        let parser = IMAPCore.CommandParser()
        XCTAssertEqual(parser.bufferLimit, 1_000)
    }
    
    func testInit_customBufferSize() {
        let parser = IMAPCore.CommandParser(bufferLimit: 80_000)
        XCTAssertEqual(parser.bufferLimit, 80_000)
    }
    
}

// MARK: - throwIfExceededBufferLimit
extension CommandParser_Tests {
    
    func testThrowIfExceededBufferLimit() {
        let parser = IMAPCore.CommandParser(bufferLimit: 2)
        var b1 = "abc" as ByteBuffer
        var b2 = "ab" as ByteBuffer
        var b3 = "a" as ByteBuffer
        XCTAssertThrowsError(try parser.throwIfExceededBufferLimit(&b1))
        XCTAssertNoThrow(try parser.throwIfExceededBufferLimit(&b2))
        XCTAssertNoThrow(try parser.throwIfExceededBufferLimit(&b3))
    }
    
}
