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

class FieldLocationExtensionTests: EncodeTestClass {}

// MARK: - Encoding

extension FieldLocationExtensionTests {
    func testEncode() {
        let inputs: [(BodyStructure.LocationAndExtensions, String, UInt)] = [
            (.init(location: "loc", extensions: []), " \"loc\"", #line),
            (.init(location: "loc", extensions: [[.number(1)]]), " \"loc\" (1)", #line),
            (.init(location: "loc", extensions: [[.number(1), .number(2)]]), " \"loc\" (1 2)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyLocationAndExtensions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
