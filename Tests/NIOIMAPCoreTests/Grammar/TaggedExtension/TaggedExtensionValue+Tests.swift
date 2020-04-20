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

class TaggedExtensionValue_Tests: EncodeTestClass {

}

// MARK: - Encoding
extension TaggedExtensionValue_Tests {

    func testEncode() {
        let inputs: [(NIOIMAP.TaggedExtensionValue, String, UInt)] = [
            (.simple(.number(123)), "123", #line),
            (.comp(["testComp"]), "((\"testComp\"))", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeTaggedExtensionValue(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
