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

class BodyFieldLanguageTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyFieldLanguageTests {
    func testEncode() {
        let inputs: [([String], String, UInt)] = [
            ([], "NIL", #line),
            (["some1"], "(\"some1\")", #line),
            (["some1", "some2", "some3"], "(\"some1\" \"some2\" \"some3\")", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyLanguages(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
