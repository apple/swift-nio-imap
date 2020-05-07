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

class BodyFieldDSPTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyFieldDSPTests {
    func testEncode() {
        let inputs: [(BodyStructure.FieldDSPData?, String, UInt)] = [
            (nil, "NIL", #line),
            (.init(string: "some", parameter: [.init(field: "f1", value: "v1")]), "(\"some\" (\"f1\" \"v1\"))", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFieldDSP(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
