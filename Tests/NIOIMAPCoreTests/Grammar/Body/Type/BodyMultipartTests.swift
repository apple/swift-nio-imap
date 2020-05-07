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

class BodyMultipartTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyMultipartTests {
    func testEncode() {
        let inputs: [(BodyStructure.Multipart, String, UInt)] = [
            (
                .bodies([
                    .singlepart(BodyStructure.Singlepart(type: .text(.mediaText("subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: nil),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) \"subtype\"",
                #line
            ),
            (
                .bodies([
                    .singlepart(BodyStructure.Singlepart(type: .text(.mediaText("subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: .parameter([], dspLanguage: nil)),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) \"subtype\" NIL",
                #line
            ),
            (
                .bodies([
                    .singlepart(BodyStructure.Singlepart(type: .text(.mediaText("subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil)),
                    .singlepart(BodyStructure.Singlepart(type: .text(.mediaText("subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 7), lines: 6)), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: nil),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5)(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 7 6) \"subtype\"",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeMultipart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_extension() {
        let inputs: [(NIOIMAP.BodyStructure.Multipart.Extension, String, UInt)] = [
            (.parameter([.field("f", value: "v")], dspLanguage: nil), "(\"f\" \"v\")", #line),
            (
                .parameter([.field("f1", value: "v1")], dspLanguage: .fieldDSP(.string("string", parameter: [.field("f2", value: "v2")]), fieldLanguage: nil)),
                "(\"f1\" \"v1\") (\"string\" (\"f2\" \"v2\"))",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtensionMultipart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
