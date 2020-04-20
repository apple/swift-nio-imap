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

class FieldLanguageLocationTests: EncodeTestClass {

}

// MARK: - Encoding
extension FieldLanguageLocationTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.FieldLanguageLocation, String, UInt)] = [
            (.language(.single("language"), location: nil), " \"language\"", #line),
            (.language(.single("language"), location: .location("location", extensions: [])), " \"language\" \"location\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFieldLanguageLocation(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
