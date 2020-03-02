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

class BodyTypeMultipartTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyTypeMultipartTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.TypeMultipart, String, UInt)] = [
            (
                .bodies([
                    .singlepart(NIOIMAP.Body.TypeSinglepart(type: .text(.init(mediaText: "subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: nil),
                "(\"TEXT\" \"subtype\" () NIL NIL \"BASE64\" 6 5) \"subtype\"",
                #line
            ),
            (
                .bodies([
                    .singlepart(NIOIMAP.Body.TypeSinglepart(type: .text(.init(mediaText: "subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: .parameter([], dspLanguage: nil)),
                "(\"TEXT\" \"subtype\" () NIL NIL \"BASE64\" 6 5) \"subtype\" ()",
                #line
            ),
            (
                .bodies([
                    .singlepart(NIOIMAP.Body.TypeSinglepart(type: .text(.init(mediaText: "subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil)),
                    .singlepart(NIOIMAP.Body.TypeSinglepart(type: .text(.init(mediaText: "subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 7), lines: 6)), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: nil),
                "(\"TEXT\" \"subtype\" () NIL NIL \"BASE64\" 6 5)(\"TEXT\" \"subtype\" () NIL NIL \"BASE64\" 7 6) \"subtype\"",
                #line
            )
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeMultipart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
