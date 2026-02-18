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
import Testing

@Suite("BodyStructure.Multipart")
struct BodyMultipartTests {
    @Test("encode multipart", arguments: [
        EncodeFixture.bodyMultipart(
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
            #"("TEXT" "SUBTYPE" NIL NIL NIL "BASE64" 6 5) "MIXED""#
        ),
        EncodeFixture.bodyMultipart(
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
            #"("TEXT" "HTML" NIL NIL NIL "BASE64" 6 5) "ALTERNATIVE" NIL"#
        ),
        EncodeFixture.bodyMultipart(
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
            #"("TEXT" "HTML" NIL NIL NIL "BASE64" 6 5)("TEXT" "PLAIN" NIL NIL NIL "BASE64" 7 6) "RELATED""#
        ),
    ])
    func encodeMultipart(_ fixture: EncodeFixture<BodyStructure.Multipart>) {
        fixture.checkEncoding()
    }

    @Test("encode extension", arguments: [
        EncodeFixture.bodyExtensionMultipart(
            .init(parameters: ["f": "v"], dispositionAndLanguage: nil),
            "(\"f\" \"v\")"
        ),
        EncodeFixture.bodyExtensionMultipart(
            .init(
                parameters: ["f1": "v1"],
                dispositionAndLanguage: .init(
                    disposition: .init(kind: "string", parameters: ["f2": "v2"]),
                    language: nil
                )
            ),
            "(\"f1\" \"v1\") (\"string\" (\"f2\" \"v2\"))"
        ),
    ])
    func encodeExtension(_ fixture: EncodeFixture<BodyStructure.Multipart.Extension>) {
        fixture.checkEncoding()
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.Multipart> {
    fileprivate static func bodyMultipart(_ input: BodyStructure.Multipart, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeBodyMultipart($1) }
        )
    }
}

extension EncodeFixture<BodyStructure.Multipart.Extension> {
    fileprivate static func bodyExtensionMultipart(
        _ input: BodyStructure.Multipart.Extension,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeBodyExtensionMultipart($1) }
        )
    }
}
