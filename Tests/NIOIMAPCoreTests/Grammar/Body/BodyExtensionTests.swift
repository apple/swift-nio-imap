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

class BodyExtensionTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyExtensionTests {
    func testEncode() {
        let inputs: [([NIOIMAP.BodyExtensionType], String, UInt)] = [
            ([.number(1)], "(1)", #line),
            ([.string("apple")], "(\"apple\")", #line),
            ([.string(nil)], "(NIL)", #line),
            ([.number(1), .number(2), .string("three")], "(1 2 \"three\")", #line),
            ([.number(1), .number(2), .string("three"), .string("four")], "(1 2 \"three\" \"four\")", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtension(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
