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

class BodyFieldParameterTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyFieldParameterTests {

    func testEncode() {
        let inputs: [([NIOIMAP.FieldParameterPair], String, UInt)] = [
            ([], "NIL", #line),
            ([.field("f1", value: "v1")], "(\"f1\" \"v1\")", #line),
            ([.field("f1", value: "v2"), .init(field: "f2", value: "v2")], "(\"f1\" \"v1\" \"f2\" \"v2\")", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFieldParameter(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
