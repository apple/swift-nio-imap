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

class BodyTypeBasicTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyTypeBasicTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.TypeBasic, String, UInt)] = [
            (.media(.type(.application, subtype: "subtype"), fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 123)), "\"APPLICATION\" \"subtype\" NIL NIL NIL \"BASE64\" 123", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeBasic(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
