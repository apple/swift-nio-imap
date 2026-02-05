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
        ),
    ])
    func encode(_ fixture: EncodeFixture<BodyStructure.Singlepart>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
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
        ),
    ])
    func `encode extension`(_ fixture: EncodeFixture<BodyStructure.Singlepart.Extension>) {
        fixture.checkEncoding()
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
