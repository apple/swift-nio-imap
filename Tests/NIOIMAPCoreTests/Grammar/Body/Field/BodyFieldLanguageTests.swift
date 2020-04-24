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

class BodyFieldLanguageTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyFieldLanguageTests {
    func testEncode() {
        let inputs: [(NIOIMAP.Body.FieldLanguage, String, UInt)] = [
            (.single(nil), "NIL", #line),
            (.single("some"), "\"some\"", #line),
            (.multiple(["some1"]), "(\"some1\")", #line),
            (.multiple(["some1", "some2", "some3"]), "(\"some1\" \"some2\" \"some3\")", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFieldLanguage(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
