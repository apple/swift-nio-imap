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

class BodyFieldEncodingTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyFieldEncodingTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.FieldEncoding, String, UInt)] = [
            (.bit7, #""7BIT""#, #line),
            (.bit8, #""8BIT""#, #line),
            (.binary, #""BINARY""#, #line),
            (.base64, #""BASE64""#, #line),
            (.quotedPrintable, #""QUOTED-PRINTABLE""#, #line),
            (.string("some"), "\"some\"", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyFieldEncoding(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
