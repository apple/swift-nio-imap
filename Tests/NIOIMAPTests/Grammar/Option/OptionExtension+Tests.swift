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
@testable import NIOIMAP

class OptionExtension_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension OptionExtension_Tests {

    func testEncode() {
        let inputs: [(NIOIMAP.OptionExtension, String, UInt)] = [
            (.standard("test", value: .string("string")), "test (\"string\")", #line),
            (.vendor(.token("token", atom: "atom"), value: nil), "token-atom", #line),
            (.vendor(.token("token", atom: "atom"), value: .string("value")), "token-atom (\"value\")", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeOptionExtension(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
