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

class AppendMessage_Tests: EncodeTestClass {

}

extension AppendMessage_Tests {
    
    func testEncode() {
        
        let inputs: [(IMAPCore.AppendMessage, String, UInt)] = [
            (.options(.flagList([], dateTime: nil, extensions: []), data: .init(byteCount: 123)), " {123}\r\n", #line),
            (.options(.flagList([], dateTime: nil, extensions: []), data: .init(byteCount: 456)), " {456}\r\n", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeAppendMessage(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
        
    }
    
}
