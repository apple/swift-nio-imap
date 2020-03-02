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

class EnableData_Tests: EncodeTestClass {

    func testEncoding() {
        let inputs: [(NIOIMAP.EnableData, String, UInt)] = [
            ([], "ENABLED", #line),
            ([.enable], "ENABLED ENABLE", #line),
            ([.enable, .condStore], "ENABLED ENABLE CONDSTORE", #line),
            ([.enable, .condStore, .auth("some")], "ENABLED ENABLE CONDSTORE AUTH=some", #line),
        ]

        for (input, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeEnableData(input)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
    
}
