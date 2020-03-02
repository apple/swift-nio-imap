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
@testable import NIOIMAP

class AppendData_Tests: EncodeTestClass {

}

extension AppendData_Tests {
    
    func testEncode() {
        
        let inputs: [(NIOIMAP.AppendData, String, UInt)] = [
            (.dataExtension(.label("label", value: .simple(.number(1)))), "label 1", #line),
            (.literal(123), "{123}\r\n", #line),
            (.literal8(456), "~{456}\r\n", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeAppendData(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
        
    }
    
}
