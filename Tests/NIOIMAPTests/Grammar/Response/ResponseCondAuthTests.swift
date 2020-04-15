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

class ResponseConditionalAuthTests: EncodeTestClass {
    
}

// MARK: - Encoding
extension ResponseConditionalAuthTests {

    func testEncode() {
        let inputs: [(IMAPCore.ResponseConditionalAuth, String, UInt)] = [
            (IMAPCore.ResponseConditionalAuth.ok(.code(nil, text: "hello")), "OK \"hello\"", #line),
            (IMAPCore.ResponseConditionalAuth.preauth(.code(nil, text: "goodbye")), "PREAUTH \"goodbye\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseConditionalAuth(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
