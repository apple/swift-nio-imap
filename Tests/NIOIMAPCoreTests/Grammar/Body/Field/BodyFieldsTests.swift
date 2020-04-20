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

class BodyFieldsTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyFieldsTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.Fields, String, UInt)] = [
            (.parameter([.field("f1", value: "v1")], id: "fieldID", description: "desc", encoding: .base64, octets: 12), "(\"f1\" \"v1\") \"fieldID\" \"desc\" \"BASE64\" 12", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFields(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
