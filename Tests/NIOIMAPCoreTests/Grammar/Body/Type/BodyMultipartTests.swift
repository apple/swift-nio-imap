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
                .init(
                    parts: [
                        .singlepart(
                            BodyStructure.Singlepart(
                                kind: .text(.init(mediaSubtype: "subtype", lineCount: 5)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 6
                                ),
                                extension: nil
                            )
                        )
                    ],
                    mediaSubtype: .mixed,
                    extension: nil
                ),
                #"("TEXT" "SUBTYPE" NIL NIL NIL "BASE64" 6 5) "MIXED""#,
                #line
            ),
            (
                .init(
                    parts: [
                        .singlepart(
                            BodyStructure.Singlepart(
                                kind: .text(.init(mediaSubtype: "html", lineCount: 5)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 6
                                ),
                                extension: nil
                            )
                        )
                    ],
                    mediaSubtype: .alternative,
                    extension: .init(parameters: [:], dispositionAndLanguage: nil)
                ),
                #"("TEXT" "HTML" NIL NIL NIL "BASE64" 6 5) "ALTERNATIVE" NIL"#,
                #line
            ),
            (
                .init(
                    parts: [
                        .singlepart(
                            BodyStructure.Singlepart(
                                kind: .text(.init(mediaSubtype: "html", lineCount: 5)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 6
                                ),
                                extension: nil
                            )
                        ),
                        .singlepart(
                            BodyStructure.Singlepart(
                                kind: .text(.init(mediaSubtype: "plain", lineCount: 6)),
                                fields: .init(
                                    parameters: [:],
                                    id: nil,
                                    contentDescription: nil,
                                    encoding: .base64,
                                    octetCount: 7
                                ),
                                extension: nil
                            )
                        ),
                    ],
                    mediaSubtype: .related,
                    extension: nil
                ),
                #"("TEXT" "HTML" NIL NIL NIL "BASE64" 6 5)("TEXT" "PLAIN" NIL NIL NIL "BASE64" 7 6) "RELATED""#,
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeBodyMultipart($0) })
    }

    func testEncode_extension() {
        let inputs: [(BodyStructure.Multipart.Extension, String, UInt)] = [
            (.init(parameters: ["f": "v"], dispositionAndLanguage: nil), "(\"f\" \"v\")", #line),
            (
                .init(
                    parameters: ["f1": "v1"],
                    dispositionAndLanguage: .init(
                        disposition: .init(kind: "string", parameters: ["f2": "v2"]),
                        language: nil
                    )
                ),
                "(\"f1\" \"v1\") (\"string\" (\"f2\" \"v2\"))",
                #line
            ),
        ]
        self.iterateInputs(inputs: inputs, encoder: { self.testBuffer.writeBodyExtensionMultipart($0) })
    }
}
