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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class BodyFieldsTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyFieldsTests {
    func testEncode() {
        let inputs: [(BodyStructure.Fields, String, UInt)] = [
            (.init(parameters: ["f1": "v1"], id: "fieldID", contentDescription: "desc", encoding: .base64, octetCount: 12), "(\"f1\" \"v1\") \"fieldID\" \"desc\" \"BASE64\" 12", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFields(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
