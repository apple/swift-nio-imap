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

class Flag_Tests: EncodeTestClass {}

// MARK: - init

extension Flag_Tests {
    // test a couple of cases to make sure that extensions are converted into non-extensions when appropriate
    // test that casing doesn't matter
    func testInit_extension() {
        let inputs: [(Flag, Flag, UInt)] = [
            (.extension("\\ANSWERED"), .answered, #line),
            (.extension("\\answered"), .answered, #line),
            (.extension("\\deleted"), .deleted, #line),
            (.extension("\\seen"), .seen, #line),
            (.extension("\\draft"), .draft, #line),
            (.extension("\\flagged"), .flagged, #line),
        ]

        for (test, expected, line) in inputs {
            XCTAssertEqual(test, expected, line: line)
        }
    }
}

// MARK: - Encoding

extension Flag_Tests {
    func testEncode() {
        let inputs: [(Flag, String, UInt)] = [
            (.answered, "\\Answered", #line),
            (.deleted, "\\Deleted", #line),
            (.draft, "\\Draft", #line),
            (.flagged, "\\Flagged", #line),
            (.seen, "\\Seen", #line),
            (.extension("\\extension"), "\\EXTENSION", #line),
            (.keyword(.forwarded), "$Forwarded", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFlag(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
