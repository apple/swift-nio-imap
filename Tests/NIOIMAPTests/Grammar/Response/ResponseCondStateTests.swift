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

class ResponseConditionalStateTests: EncodeTestClass {

}

// MARK: - Encoding
extension ResponseConditionalStateTests {

    func testEncode() {
        let inputs: [(IMAPCore.ResponseConditionalState, String, UInt)] = [
            (IMAPCore.ResponseConditionalState.bad(.code(.parse, text: "something")), "BAD [PARSE] \"something\"", #line),
            (IMAPCore.ResponseConditionalState.ok(.code(.alert, text: "error")), "OK [ALERT] \"error\"", #line),
            (IMAPCore.ResponseConditionalState.no(.code(.readOnly, text: "everything")), "NO [READ-ONLY] \"everything\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeResponseConditionalState(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
