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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class EntryTypeResponse_Tests: EncodeTestClass {
    func testEncoding() {
        let inputs: [(EntryKindResponse, String, UInt)] = [
            (.private, "priv", #line),
            (.shared, "shared", #line),
        ]

        for (input, expected, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeEntryKindResponse(input)
            XCTAssertEqual(size, expected.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expected, line: line)
        }
    }
}
