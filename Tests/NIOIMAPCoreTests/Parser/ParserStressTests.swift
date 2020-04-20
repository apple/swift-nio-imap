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
import NIOTestUtils
import NIOIMAP
import NIOIMAPCore

import XCTest

final class ParserStressTests: XCTestCase {
    
    private var channel: EmbeddedChannel!
    
    override func setUp() {
        XCTAssertNil(self.channel)
        self.channel = EmbeddedChannel(handler: ByteToMessageHandler(NIOIMAP.CommandDecoder()))
    }
    
    override func tearDown() {
        XCTAssertNotNil(self.channel)
        XCTAssertNoThrow(XCTAssertTrue(try channel.finish().isClean))
        self.channel = nil
    }
    
    // Test that we eventually stop parsing a single item
    // e.g. mailbox with name xxxxxxxxxxxxxxxxxx...
    func testArbitraryLongMailboxName () {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString("CREATE \"")
        for _ in 0 ..< 20_000 {
            longBuffer.writeString("xxxx")
        }

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? NIOIMAP.IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertEqual(error.parserError as? NIOIMAP.ParsingError, .lineTooLong)
        }
    }
    
    // Test that we eventually stop parsing infinite parameters
    // e.g. a sequence of numbers 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ...
    func testArbitraryNumberOfFlags () {
        var longBuffer = self.channel.allocator.buffer(capacity: 90_000)
        longBuffer.writeString("STORE 1, ")
        for i in 2 ..< 20_000 {
            longBuffer.writeString("\(i), ")
        }

        XCTAssertThrowsError(try self.channel.writeInbound(longBuffer)) { _error in
            guard let error = _error as? NIOIMAP.IMAPDecoderError else {
                XCTFail("\(_error)")
                return
            }
            XCTAssertEqual(error.parserError as? NIOIMAP.ParsingError, .lineTooLong)
        }
    }

}
