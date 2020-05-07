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
@testable import NIOIMAPCore
import XCTest

class ResponseConditionalAuthTests: EncodeTestClass {}

// MARK: - Encoding

extension ResponseConditionalAuthTests {
    func testEncode() {
        let inputs: [(NIOIMAP.ResponseConditionalAuth, String, UInt)] = [
            (NIOIMAP.ResponseConditionalAuth.ok(.init(code: nil, text: "hello")), "OK hello", #line),
            (NIOIMAP.ResponseConditionalAuth.preauth(.init(code: nil, text: "goodbye")), "PREAUTH goodbye", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseConditionalAuth(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
