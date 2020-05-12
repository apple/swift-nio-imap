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
                .init(bodies: [
                    .singlepart(BodyStructure.Singlepart(type: .text(.init(mediaText: "subtype", lines: 5)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: nil),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) \"subtype\"",
                #line
            ),
            (
                .init(bodies: [
                    .singlepart(BodyStructure.Singlepart(type: .text(.init(mediaText: "subtype", lines: 5)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6), extension: nil)),
                ], mediaSubtype: "subtype", multipartExtension: .init(parameters: [], dspLanguage: nil)),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) \"subtype\" NIL",
                #line
            ),
            (
                .init(bodies: [
                    .singlepart(BodyStructure.Singlepart(type: .text(.init(mediaText: "subtype", lines: 5)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6), extension: nil)),
                    .singlepart(BodyStructure.Singlepart(type: .text(.init(mediaText: "subtype", lines: 6)), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6), extension: nil)),
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
        let inputs: [(BodyStructure.Multipart.Extension, String, UInt)] = [
            (.init(parameters: [.init(field: "f", value: "v")], dspLanguage: nil), "(\"f\" \"v\")", #line),
            (
                .init(parameters: [.init(field: "f1", value: "v1")], dspLanguage: .init(fieldDSP: .init(string: "string", parameter: [.init(field: "f2", value: "v2")]), fieldLanguage: nil)),
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
