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
import OrderedCollections
import XCTest

class NamespaceResponseExtension_Tests: EncodeTestClass {}

// MARK: - Encoding

extension NamespaceResponseExtension_Tests {
    func testEncode() {
        let inputs: [(OrderedDictionary<ByteBuffer, [ByteBuffer]>, String, UInt)] = [
            ([:], "", #line),
            (["str1": ["str2"]], " \"str1\" (\"str2\")", #line),
            (
                [
                    "str1": ["str2"],
                    "str3": ["str4"],
                    "str5": ["str6"],
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
