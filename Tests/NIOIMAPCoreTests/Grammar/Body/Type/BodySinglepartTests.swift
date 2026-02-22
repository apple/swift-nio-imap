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

@Suite("BodyStructure.Singlepart")
struct BodySinglepartTests {}

extension BodySinglepartTests {
    @Test(arguments: [
        EncodeFixture.bodySinglepart(
            .init(
                kind: .basic(.init(topLevel: .application, sub: "jpeg")),
                fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                extension: nil
            ),
            #""APPLICATION" "JPEG" NIL NIL NIL "BASE64" 6"#
        ),
        EncodeFixture.bodySinglepart(
            .init(
                kind: .basic(.init(topLevel: .application, sub: "jpeg")),
                fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 7),
                extension: .init(digest: "md5", dispositionAndLanguage: nil)
            ),
            #""APPLICATION" "JPEG" NIL NIL NIL "BASE64" 7 "md5""#
        ),
        EncodeFixture.bodySinglepart(
            .init(
                kind: .text(.init(mediaSubtype: "html", lineCount: 5)),
                fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                extension: nil
            ),
            #""TEXT" "HTML" NIL NIL NIL "BASE64" 6 5"#
        ),
        EncodeFixture.bodySinglepart(
            .init(
                kind: .message(
                    .init(
                        message: .rfc822,
                        envelope: .init(
                            date: "date",
                            subject: nil,
                            from: [],
                            sender: [],
                            reply: [],
                            to: [],
                            cc: [],
                            bcc: [],
                            inReplyTo: nil,
                            messageID: nil
                        ),
                        body: .singlepart(
                            .init(
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
                        ),
                        lineCount: 8
                    )
                ),
                fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                extension: nil
            ),
            #""MESSAGE" "RFC822" NIL NIL NIL "BASE64" 6 ("date" NIL NIL NIL NIL NIL NIL NIL NIL NIL) ("TEXT" "SUBTYPE" NIL NIL NIL "BASE64" 6 5) 8"#
        )
    ])
    func encode(_ fixture: EncodeFixture<BodyStructure.Singlepart>) {
        fixture.checkEncoding()
    }

    @Test(
        "encode extension",
        arguments: [
            EncodeFixture.bodySinglepartExtension(
                .init(digest: nil, dispositionAndLanguage: nil),
                "NIL"
            ),
            EncodeFixture.bodySinglepartExtension(
                .init(digest: "md5", dispositionAndLanguage: nil),
                "\"md5\""
            ),
            EncodeFixture.bodySinglepartExtension(
                .init(
                    digest: "md5",
                    dispositionAndLanguage: .init(disposition: .init(kind: "string", parameters: [:]), language: nil)
                ),
                "\"md5\" (\"string\" NIL)"
            )
        ]
    )
    func encodeExtension(_ fixture: EncodeFixture<BodyStructure.Singlepart.Extension>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.bodySinglepart(
            #""AUDIO" "alternative" NIL NIL NIL "BASE64" 1"#,
            "\r\n",
            expected: .success(
                .init(
                    kind: .basic(.init(topLevel: .audio, sub: .alternative)),
                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 1),
                    extension: nil
                )
            )
        ),
        ParseFixture.bodySinglepart(
            #""APPLICATION" "mixed" NIL "id" "description" "7BIT" 2"#,
            "\r\n",
            expected: .success(
                .init(
                    kind: .basic(.init(topLevel: .application, sub: .mixed)),
                    fields: .init(
                        parameters: [:],
                        id: "id",
                        contentDescription: "description",
                        encoding: .sevenBit,
                        octetCount: 2
                    ),
                    extension: nil
                )
            )
        ),
        ParseFixture.bodySinglepart(
            #""VIDEO" "related" ("f1" "v1") NIL NIL "8BIT" 3"#,
            "\r\n",
            expected: .success(
                .init(
                    kind: .basic(.init(topLevel: .video, sub: .related)),
                    fields: .init(
                        parameters: ["f1": "v1"],
                        id: nil,
                        contentDescription: nil,
                        encoding: .eightBit,
                        octetCount: 3
                    ),
                    extension: nil
                )
            )
        ),
        ParseFixture.bodySinglepart(
            #""MESSAGE" "RFC822" NIL NIL NIL "BASE64" 4 (NIL NIL NIL NIL NIL NIL NIL NIL NIL NIL) ("IMAGE" "related" NIL NIL NIL "BINARY" 5) 8"#,
            "\r\n",
            expected: .success(
                .init(
                    kind: .message(
                        .init(
                            message: .rfc822,
                            envelope: Envelope(
                                date: nil,
                                subject: nil,
                                from: [],
                                sender: [],
                                reply: [],
                                to: [],
                                cc: [],
                                bcc: [],
                                inReplyTo: nil,
                                messageID: nil
                            ),
                            body: .singlepart(
                                .init(
                                    kind: .basic(.init(topLevel: .image, sub: .related)),
                                    fields: .init(
                                        parameters: [:],
                                        id: nil,
                                        contentDescription: nil,
                                        encoding: .binary,
                                        octetCount: 5
                                    )
                                )
                            ),
                            lineCount: 8
                        )
                    ),
                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 4),
                    extension: nil
                )
            )
        ),
        ParseFixture.bodySinglepart(
            #""TEXT" "media" NIL NIL NIL "QUOTED-PRINTABLE" 1 2"#,
            "\r\n",
            expected: .success(
                .init(
                    kind: .text(.init(mediaSubtype: "media", lineCount: 2)),
                    fields: .init(
                        parameters: [:],
                        id: nil,
                        contentDescription: nil,
                        encoding: .quotedPrintable,
                        octetCount: 1
                    ),
                    extension: nil
                )
            )
        )
    ])
    func parse(_ fixture: ParseFixture<BodyStructure.Singlepart>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<BodyStructure.Singlepart> {
    fileprivate static func bodySinglepart(
        _ input: BodyStructure.Singlepart,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeBodySinglepart($1) }
        )
    }
}

extension EncodeFixture<BodyStructure.Singlepart.Extension> {
    fileprivate static func bodySinglepartExtension(
        _ input: BodyStructure.Singlepart.Extension,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeBodyExtensionSinglePart($1) }
        )
    }
}

extension ParseFixture<BodyStructure.Singlepart> {
    fileprivate static func bodySinglepart(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBodyKindSinglePart
        )
    }
}
