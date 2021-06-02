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

class BodyMultipartTests: EncodeTestClass {}

// MARK: - Encoding

extension BodyMultipartTests {
    func testEncode() {
        let inputs: [(BodyStructure.Multipart, String, UInt)] = [
            (
                .init(parts: [
                    .singlepart(BodyStructure.Singlepart(kind: .text(.init(mediaText: "subtype", lineCount: 5)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6), extension: nil)),
                ], mediaSubtype: .mixed, extension: nil),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) \"multipart/mixed\"",
                #line
            ),
            (
                .init(parts: [
                    .singlepart(BodyStructure.Singlepart(kind: .text(.init(mediaText: "subtype", lineCount: 5)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6), extension: nil)),
                ], mediaSubtype: .alternative, extension: .init(parameters: [:], dispositionAndLanguage: nil)),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) \"multipart/alternative\" NIL",
                #line
            ),
            (
                .init(parts: [
                    .singlepart(BodyStructure.Singlepart(kind: .text(.init(mediaText: "subtype", lineCount: 5)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6), extension: nil)),
                    .singlepart(BodyStructure.Singlepart(kind: .text(.init(mediaText: "subtype", lineCount: 6)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 7), extension: nil)),
                ], mediaSubtype: .related, extension: nil),
                "(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5)(\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 7 6) \"multipart/related\"",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeBodyMultipart($0) })
    }

    func testEncode_extension() {
        let inputs: [(BodyStructure.Multipart.Extension, String, UInt)] = [
            (.init(parameters: ["f": "v"], dispositionAndLanguage: nil), "(\"f\" \"v\")", #line),
            (
                .init(parameters: ["f1": "v1"], dispositionAndLanguage: .init(disposition: .init(kind: "string", parameters: ["f2": "v2"]), language: nil)),
                "(\"f1\" \"v1\") (\"string\" (\"f2\" \"v2\"))",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeBodyExtensionMultipart($0) })
    }

    func testEncode_mediaSubtype() {
        let inputs: [(BodyStructure.MediaSubtype, String, UInt)] = [
            (.alternative, "\"multipart/alternative\"", #line),
            (.mixed, "\"multipart/mixed\"", #line),
            (.related, "\"multipart/related\"", #line),
            (.init("other"), "\"other\"", #line),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeMediaSubtype($0) })
    }
}
