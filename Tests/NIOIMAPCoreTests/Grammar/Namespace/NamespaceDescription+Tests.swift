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

class NamespaceDescription_Tests: EncodeTestClass {}

// MARK: - Encoding

extension NamespaceDescription_Tests {
    func testEncode() {
        let inputs: [(NamespaceDescription, String, UInt)] = [
            (.init(string: "string", char: nil, responseExtensions: [:]), "(\"string\" NIL)", #line),
            (.init(string: "string", char: "a", responseExtensions: [:]), "(\"string\" \"a\")", #line),
            (.init(string: "string", char: nil, responseExtensions: ["str2": ["str3"]]), "(\"string\" NIL \"str2\" (\"str3\"))", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            let size = self.testBuffer.writeNamespaceDescription(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
