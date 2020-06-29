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

final class CommandParser_Tests: XCTestCase {}

extension CommandParser_Tests {
    
    func testThrowsIfMissingBytes() {
        
        let encoder = CommandEncoder()
        
        var out = ByteBuffer()
        XCTAssertNoThrow(try encoder.encode(data: .append(.start(tag: "1", appendingTo: .inbox)), out: &out))
        
        out.clear()
        XCTAssertNoThrow(try encoder.encode(data: .append(.beginMessage(messsage: .init(options: .init(flagList: [], extensions: []), data: .init(byteCount: 10)))), out: &out))
        
        out.clear()
        XCTAssertNoThrow(try encoder.encode(data: .append(.messageBytes("12345")), out: &out))
        
        out.clear()
        XCTAssertThrowsError(try encoder.encode(data: .append(.endMessage), out: &out))
        
    }
    
}
