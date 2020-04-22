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
@testable import NIOIMAPCore

class Flag_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension Flag_Tests {

    func testEncode() {
        let inputs: [(NIOIMAP.Flag, String, UInt)] = [
            (.answered, "\\Answered", #line),
            (.deleted, "\\Deleted", #line),
            (.draft, "\\Draft", #line),
            (.flagged, "\\Flagged", #line),
            (.seen, "\\Seen", #line),
            (.extension("extension"), "\\extension", #line),
            (.keyword(.forwarded), "$FORWARDED", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeFlag(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

}
