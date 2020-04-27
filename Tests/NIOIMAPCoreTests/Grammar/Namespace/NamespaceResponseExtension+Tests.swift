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

class NamespaceResponseExtension_Tests: EncodeTestClass {}

// MARK: - Encoding

extension NamespaceResponseExtension_Tests {
    func testEncode() {
        let inputs: [(NIOIMAP.NamespaceResponseExtension, String, UInt)] = [
            (.string("string1", array: ["string2"]), " \"string1\" (\"string2\")", #line),
            (.string("str1", array: ["str2", "str3", "str4", "str5"]), " \"str1\" (\"str2\" \"str3\" \"str4\" \"str5\")", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeNamespaceResponseExtension(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let inputs: [([NIOIMAP.NamespaceResponseExtension], String, UInt)] = [
            ([], "", #line),
            ([.string("str1", array: ["str2"])], " \"str1\" (\"str2\")", #line),
            (
                [
                    .string("str1", array: ["str2"]),
                    .string("str3", array: ["str4"]),
                    .string("str5", array: ["str6"]),
                ],
                " \"str1\" (\"str2\") \"str3\" (\"str4\") \"str5\" (\"str6\")", #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeNamespaceResponseExtensions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
