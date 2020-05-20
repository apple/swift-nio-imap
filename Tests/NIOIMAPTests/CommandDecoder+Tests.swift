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
@testable import NIOIMAPCore
import NIOTestUtils

import XCTest

final class CommandDecoder_Tests: XCTestCase {}

extension CommandDecoder_Tests {
    
    func testDripfeed() {
        
        // full command = tag APPEND box (\\Seen) {1+}\r\na
        var drip = ByteBufferAllocator().buffer(capacity: 1)
        drip.writeString("tag LOGIN \"\" {0+}\r\nt")
        
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(CommandDecoder()), loop: .init())
        do {
            try channel.writeInbound(drip)
        } catch {
            XCTFail("\(error)")
            return
        }
        
        XCTAssertNoThrow(try channel.readInbound(as: CommandDecoder.PartialCommandStream.self))
        XCTAssertNoThrow(try channel.readInbound(as: CommandDecoder.PartialCommandStream.self))
    }
    
}
