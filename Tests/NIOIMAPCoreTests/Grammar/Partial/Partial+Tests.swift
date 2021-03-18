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

class Partial_Tests: EncodeTestClass {}

// MARK: - Encoding

extension Partial_Tests {
    func testEncode() {
        let inputs: [(ClosedRange<UInt32>, String, UInt)] = [
            /// Encoded format is `<offset.count>`:
            (0 ... 199, "<0.200>", #line),
            (1 ... 2, "<1.2>", #line),
            (10 ... 20, "<10.11>", #line),
            (100 ... 199, "<100.100>", #line),
            (400 ... 479, "<400.80>", #line),
            (843 ... 1_369, "<843.527>", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            let size = self.testBuffer.writePartial(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
