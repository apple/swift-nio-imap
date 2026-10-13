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

import Foundation
import NIO
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import OrderedCollections
import Testing

extension ResponseParserTests {
    @Test(
        "parse response stream",
        arguments: [
            ResponseStreamFixture(
                input: "+ OK Continue",
                expected: [.continuationRequest(.responseText(.init(text: "OK Continue")))]
            ),
            ResponseStreamFixture(
                input: "1 OK NOOP Completed",
                expected: [.response(.tagged(.init(tag: "1", state: .ok(.init(text: "NOOP Completed")))))]
            ),
            ResponseStreamFixture(
                input: "* 999 FETCH (FLAGS (\\Seen))",
                expected: [
                    .response(.fetch(.start(999))),
                    .response(.fetch(.simpleAttribute(.flags([.seen])))),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 12190 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(12190))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 47)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "utf-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .quotedPrintable,
                                                                octetCount: 1772
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "HTML", lineCount: 40)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "utf-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .quotedPrintable,
                                                                octetCount: 2778
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .alternative,
                                                extension: .init(
                                                    parameters: [
                                                        "BOUNDARY": "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015"
                                                    ],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 12194 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 3034 50 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "_____5C088583DDA30A778CEA0F5BFE2856D1") NIL NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(12194))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "HTML", lineCount: 50)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "UTF-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .quotedPrintable,
                                                                octetCount: 3034
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    )
                                                ],
                                                mediaSubtype: .alternative,
                                                extension: .init(
                                                    parameters: ["BOUNDARY": "_____5C088583DDA30A778CEA0F5BFE2856D1"],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 12180 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 221 5 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "7BIT" 2075 20 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c" "CHARSET" "UTF-8") NIL NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(12180))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 5)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "UTF-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .sevenBit,
                                                                octetCount: 221
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "HTML", lineCount: 20)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "UTF-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .sevenBit,
                                                                octetCount: 2075
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .alternative,
                                                extension: .init(
                                                    parameters: [
                                                        "BOUNDARY":
                                                            "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c",
                                                        "CHARSET": "UTF-8",
                                                    ],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 12182 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 239844 4078 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 239844 4078 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "===============8996999810533184102==") NIL NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(12182))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 4078)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "utf-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .quotedPrintable,
                                                                octetCount: 239844
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "HTML", lineCount: 4078)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "utf-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .quotedPrintable,
                                                                octetCount: 239844
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .alternative,
                                                extension: .init(
                                                    parameters: ["BOUNDARY": "===============8996999810533184102=="],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input: #"* 12183 FETCH (BODYSTRUCTURE ("TEXT" "HTML" NIL NIL NIL "BINARY" 28803 603 NIL NIL NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(12183))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "HTML", lineCount: 603)),
                                                fields: .init(
                                                    parameters: [:],
                                                    id: nil,
                                                    contentDescription: nil,
                                                    encoding: .binary,
                                                    octetCount: 28803
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 12184 FETCH (BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "utf-8") "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>" NIL "BASE64" 2340 30 NIL NIL ("EN-US") NIL))"#,
                expected: [
                    .response(.fetch(.start(12184))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .singlepart(
                                            .init(
                                                kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 30)),
                                                fields: .init(
                                                    parameters: ["CHARSET": "utf-8"],
                                                    id: "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>",
                                                    contentDescription: nil,
                                                    encoding: .base64,
                                                    octetCount: 2340
                                                ),
                                                extension: .init(
                                                    digest: nil,
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: ["EN-US"],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 12187 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 6990 170 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 18865 274 NIL NIL NIL NIL)("APPLICATION" "OCTET-STREAM" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.key") NIL NIL "BASE64" 4876604 NIL ("ATTACHMENT" ("FILENAME" "Whiteboard on Webex.key")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 1143 17 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.pdf") NIL NIL "BASE64" 1191444 NIL ("INLINE" ("FILENAME" "Whiteboard on Webex.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 2217 32 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0666" "NAME" "Resume.pdf") NIL NIL "BASE64" 217550 NIL ("INLINE" ("FILENAME" "Resume.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 4450 62 NIL NIL NIL NIL) "MIXED" ("BOUNDARY" "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F") NIL NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(12187))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 170)),
                                                            fields: .init(
                                                                parameters: ["CHARSET": "utf-8"],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .quotedPrintable,
                                                                octetCount: 6990
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                    .multipart(
                                                        .init(
                                                            parts: [
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .text(
                                                                            .init(mediaSubtype: "HTML", lineCount: 274)
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["CHARSET": "utf-8"],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .quotedPrintable,
                                                                            octetCount: 18865
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: nil,
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .basic(
                                                                            .init(
                                                                                topLevel: .application,
                                                                                sub: .init("OCTET-STREAM")
                                                                            )
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: [
                                                                                "X-UNIX-MODE": "0644",
                                                                                "NAME": "Whiteboard on Webex.key",
                                                                            ],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .base64,
                                                                            octetCount: 4_876_604
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: .init(
                                                                                    kind: "ATTACHMENT",
                                                                                    parameters: [
                                                                                        "FILENAME":
                                                                                            "Whiteboard on Webex.key"
                                                                                    ]
                                                                                ),
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .text(
                                                                            .init(mediaSubtype: "HTML", lineCount: 17)
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["CHARSET": "us-ascii"],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .quotedPrintable,
                                                                            octetCount: 1143
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: nil,
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .basic(
                                                                            .init(
                                                                                topLevel: .application,
                                                                                sub: .init("PDF")
                                                                            )
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: [
                                                                                "X-UNIX-MODE": "0644",
                                                                                "NAME": "Whiteboard on Webex.pdf",
                                                                            ],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .base64,
                                                                            octetCount: 1_191_444
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: .init(
                                                                                    kind: "INLINE",
                                                                                    parameters: [
                                                                                        "FILENAME":
                                                                                            "Whiteboard on Webex.pdf"
                                                                                    ]
                                                                                ),
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .text(
                                                                            .init(mediaSubtype: "HTML", lineCount: 32)
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["CHARSET": "us-ascii"],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .quotedPrintable,
                                                                            octetCount: 2217
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: nil,
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .basic(
                                                                            .init(
                                                                                topLevel: .application,
                                                                                sub: .init("PDF")
                                                                            )
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: [
                                                                                "X-UNIX-MODE": "0666",
                                                                                "NAME": "Resume.pdf",
                                                                            ],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .base64,
                                                                            octetCount: 217550
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: .init(
                                                                                    kind: "INLINE",
                                                                                    parameters: [
                                                                                        "FILENAME": "Resume.pdf"
                                                                                    ]
                                                                                ),
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .text(
                                                                            .init(mediaSubtype: "HTML", lineCount: 62)
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["CHARSET": "utf-8"],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .quotedPrintable,
                                                                            octetCount: 4450
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: nil,
                                                                                language: .init(
                                                                                    languages: [],
                                                                                    location: .init(
                                                                                        location: nil,
                                                                                        extensions: []
                                                                                    )
                                                                                )
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                            ],
                                                            mediaSubtype: .mixed,
                                                            extension: .init(
                                                                parameters: [
                                                                    "BOUNDARY":
                                                                        "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2"
                                                                ],
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(
                                                                        languages: [],
                                                                        location: .init(location: nil, extensions: [])
                                                                    )
                                                                )
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .alternative,
                                                extension: .init(
                                                    parameters: [
                                                        "BOUNDARY": "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F"
                                                    ],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(
                                                            languages: [],
                                                            location: .init(location: nil, extensions: [])
                                                        )
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 53 FETCH (BODYSTRUCTURE (("TEXT" "HTML" NIL NIL NIL "7BIT" 151 0 NIL NIL NIL) "MIXED" ("BOUNDARY" "----=rfsewr") NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(53))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .singlepart(
                                                        .init(
                                                            kind: .text(.init(mediaSubtype: "HTML", lineCount: 0)),
                                                            fields: BodyStructure.Fields(
                                                                parameters: [:],
                                                                id: nil,
                                                                contentDescription: nil,
                                                                encoding: .sevenBit,
                                                                octetCount: 151
                                                            ),
                                                            extension: BodyStructure.Singlepart.Extension(
                                                                digest: nil,
                                                                dispositionAndLanguage:
                                                                    BodyStructure.DispositionAndLanguage(
                                                                        disposition: nil,
                                                                        language: BodyStructure.LanguageLocation(
                                                                            languages: [],
                                                                            location: nil
                                                                        )
                                                                    )
                                                            )
                                                        )
                                                    )
                                                ],
                                                mediaSubtype: .mixed,
                                                extension: .init(
                                                    parameters: ["BOUNDARY": "----=rfsewr"],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(languages: [], location: nil)
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 433 FETCH (BODYSTRUCTURE (((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 710 20 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4323 42 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "4__=rtfgha") NIL NIL)("IMAGE" "JPEG" ("NAME" "bike.jpeg") "<2__=lgkfjr>" NIL "BASE64" 64 NIL ("INLINE" ("FILENAME" "bike.jpeg")) NIL) "RELATED" ("BOUNDARY" "0__=rtfgaa") NIL NIL)("APPLICATION" "PDF" ("NAME" "title.pdf") "<5__=jlgkfr>" NIL "BASE64" 333980 NIL ("ATTACHMENT" ("FILENAME" "list.pdf")) NIL) "MIXED" ("BOUNDARY" "1__=tfgrhs") NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(433))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .multipart(
                                                        .init(
                                                            parts: [
                                                                .multipart(
                                                                    .init(
                                                                        parts: [
                                                                            .singlepart(
                                                                                .init(
                                                                                    kind: .text(
                                                                                        .init(
                                                                                            mediaSubtype: "PLAIN",
                                                                                            lineCount: 20
                                                                                        )
                                                                                    ),
                                                                                    fields: .init(
                                                                                        parameters: [
                                                                                            "CHARSET": "ISO-8859-1"
                                                                                        ],
                                                                                        id: nil,
                                                                                        contentDescription: nil,
                                                                                        encoding: .quotedPrintable,
                                                                                        octetCount: 710
                                                                                    ),
                                                                                    extension: .init(
                                                                                        digest: nil,
                                                                                        dispositionAndLanguage: .init(
                                                                                            disposition: nil,
                                                                                            language: .init(
                                                                                                languages: [])
                                                                                        )
                                                                                    )
                                                                                )
                                                                            ),
                                                                            .singlepart(
                                                                                .init(
                                                                                    kind: .text(
                                                                                        .init(
                                                                                            mediaSubtype: "HTML",
                                                                                            lineCount: 42
                                                                                        )
                                                                                    ),
                                                                                    fields: .init(
                                                                                        parameters: [
                                                                                            "CHARSET": "ISO-8859-1"
                                                                                        ],
                                                                                        id: nil,
                                                                                        contentDescription: nil,
                                                                                        encoding: .quotedPrintable,
                                                                                        octetCount: 4323
                                                                                    ),
                                                                                    extension: .init(
                                                                                        digest: nil,
                                                                                        dispositionAndLanguage: .init(
                                                                                            disposition: .init(
                                                                                                kind: "INLINE",
                                                                                                parameters: [:]
                                                                                            ),
                                                                                            language: .init(
                                                                                                languages: [])
                                                                                        )
                                                                                    )
                                                                                )
                                                                            ),
                                                                        ],
                                                                        mediaSubtype: .alternative,
                                                                        extension: .init(
                                                                            parameters: ["BOUNDARY": "4__=rtfgha"],
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: nil,
                                                                                language: .init(languages: [])
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .basic(
                                                                            .init(topLevel: .image, sub: .init("JPEG"))
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["NAME": "bike.jpeg"],
                                                                            id: "<2__=lgkfjr>",
                                                                            contentDescription: nil,
                                                                            encoding: .base64,
                                                                            octetCount: 64
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: .init(
                                                                                    kind: "INLINE",
                                                                                    parameters: [
                                                                                        "FILENAME": "bike.jpeg"
                                                                                    ]
                                                                                ),
                                                                                language: .init(languages: [])
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                            ],
                                                            mediaSubtype: .related,
                                                            extension: .init(
                                                                parameters: ["BOUNDARY": "0__=rtfgaa"],
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(languages: [])
                                                                )
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(
                                                                .init(topLevel: .application, sub: .init("PDF"))
                                                            ),
                                                            fields: .init(
                                                                parameters: ["NAME": "title.pdf"],
                                                                id: "<5__=jlgkfr>",
                                                                contentDescription: nil,
                                                                encoding: .base64,
                                                                octetCount: 333980
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: .init(
                                                                        kind: "ATTACHMENT",
                                                                        parameters: ["FILENAME": "list.pdf"]
                                                                    ),
                                                                    language: .init(languages: [])
                                                                )
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .mixed,
                                                extension: .init(
                                                    parameters: ["BOUNDARY": "1__=tfgrhs"],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(languages: [])
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input:
                    #"* 234 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 410 24 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 1407 30 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "hqjksdm1__=") NIL NIL)("IMAGE" "PNG" ("NAME" "screenshot.png") "<3__=f2fcxd>" NIL "BASE64" 40655 NIL ("INLINE" ("FILENAME" "screenshot.png")) NIL) "RELATED" ("BOUNDARY" "5__=hsdqjkm") NIL NIL))"#,
                expected: [
                    .response(.fetch(.start(234))),
                    .response(
                        .fetch(
                            .simpleAttribute(
                                .body(
                                    .valid(
                                        .multipart(
                                            .init(
                                                parts: [
                                                    .multipart(
                                                        .init(
                                                            parts: [
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .text(
                                                                            .init(mediaSubtype: "PLAIN", lineCount: 24)
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["CHARSET": "ISO-8859-1"],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .quotedPrintable,
                                                                            octetCount: 410
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: nil,
                                                                                language: .init(languages: [])
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                                .singlepart(
                                                                    .init(
                                                                        kind: .text(
                                                                            .init(mediaSubtype: "HTML", lineCount: 30)
                                                                        ),
                                                                        fields: .init(
                                                                            parameters: ["CHARSET": "ISO-8859-1"],
                                                                            id: nil,
                                                                            contentDescription: nil,
                                                                            encoding: .quotedPrintable,
                                                                            octetCount: 1407
                                                                        ),
                                                                        extension: .init(
                                                                            digest: nil,
                                                                            dispositionAndLanguage: .init(
                                                                                disposition: .init(
                                                                                    kind: "INLINE",
                                                                                    parameters: [:]
                                                                                ),
                                                                                language: .init(languages: [])
                                                                            )
                                                                        )
                                                                    )
                                                                ),
                                                            ],
                                                            mediaSubtype: .alternative,
                                                            extension: .init(
                                                                parameters: ["BOUNDARY": "hqjksdm1__="],
                                                                dispositionAndLanguage: .init(
                                                                    disposition: nil,
                                                                    language: .init(languages: [])
                                                                )
                                                            )
                                                        )
                                                    ),
                                                    .singlepart(
                                                        .init(
                                                            kind: .basic(.init(topLevel: .image, sub: .init("PNG"))),
                                                            fields: BodyStructure.Fields(
                                                                parameters: ["NAME": "screenshot.png"],
                                                                id: "<3__=f2fcxd>",
                                                                contentDescription: nil,
                                                                encoding: .base64,
                                                                octetCount: 40655
                                                            ),
                                                            extension: .init(
                                                                digest: nil,
                                                                dispositionAndLanguage: .init(
                                                                    disposition: .init(
                                                                        kind: "INLINE",
                                                                        parameters: ["FILENAME": "screenshot.png"]
                                                                    ),
                                                                    language: .init(languages: [])
                                                                )
                                                            )
                                                        )
                                                    ),
                                                ],
                                                mediaSubtype: .related,
                                                extension: .init(
                                                    parameters: ["BOUNDARY": "5__=hsdqjkm"],
                                                    dispositionAndLanguage: .init(
                                                        disposition: nil,
                                                        language: .init(languages: [])
                                                    )
                                                )
                                            )
                                        )
                                    ),
                                    hasExtensionData: true
                                )
                            )
                        )
                    ),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input: "* 12183 FETCH (UID 2282556735 PREVIEW {3}\r\nabc FLAGS (\\Seen))",
                expected: [
                    .response(.fetch(.start(12183))),
                    .response(.fetch(.simpleAttribute(.uid(2_282_556_735)))),
                    .response(.fetch(.simpleAttribute(.preview(.init("abc"))))),
                    .response(.fetch(.simpleAttribute(.flags([.seen])))),
                    .response(.fetch(.finish)),
                ]
            ),
            ResponseStreamFixture(
                input: #"""
                    * 61785 FETCH (UID 127139 RFC822.SIZE 1008880 BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 50561 1112 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 546481 8065 NIL NIL NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "5mXzRqbGv/TuLF6tt8xeaTEK6jd/gBgAY3XUG85B9s62ixIvEnoCeXRBcG9wznRsUPSHerV324xgnpBSueR9s8BcGf+nkPfhtxxDnfuVrjJBpQSKj0lbPY/Npq+Ak7/f") "<2514DF6C-D2FA-46AD-B0DC-2CCF2358624A>" NIL "BASE64" 21258 NIL ("INLINE" ("FILENAME" "UesGpGJHsr20S9xoFoOnVOUe0xsqcOHcMUqZzJ8O0PhcZsBEUoMS9wmpnWyuGlTeypczpIqTpZknCdtg6iTESUOke7lUE/RZdi4hFTtD4GZpWGZm4CA5ApFjXmjw.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "6MEADWH7I2HpWPPz2K.png") "<9D94C1DE-808F-44E6-A4AB-AA97043B5899>" NIL "BASE64" 64938 NIL ("INLINE" ("FILENAME" "6MEADWH7I2HpWPPz2K.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "WE4fsw0y6p6V17F3UfrFhpYM1lrItLSgznkEBLLUWUUwk1Qu6NtkscCSp9KBr4qKUalGsfJL6ODQQzjMdocPuwK2LNIzp9o/gob97bIjURtGg/FoTMXwOCd2RzBRj/aA") "<BA1253E9-4D29-4DC2-AB7F-61E31D6983AC>" NIL "BASE64" 32806 NIL ("INLINE" ("FILENAME" "zQSAL4irVrBiICQ5gLC6yVGjmuviR4dpaL8j/H24kIezbAO4fnrtJxeBXcya/RmINP1Zi51W/30tEu3nlXdniYXzl4R5kC4jiD6gcwbyrKB8H/GyAAr8AV1OB8/XRV8F.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "uvlE2DBWSit0TrFrfgq02LlrISPRZUFYRD7myv32Or4OMTHKwby0k9riwJVm4N5z93SXzsHcj9Srj/cWIZuhDV95NPlfVZJbG1ukKwBGKajU7kGvjB+5IhyUy02y.png") "<840604E1-282C-424C-85E6-E9C31CA8D3E5>" NIL "BASE64" 122432 NIL ("INLINE" ("FILENAME" "PG+0O0vAYNGhK77Iy6EEDgJyLEKZ/WNlfHuVkdRU6lAz7+Xn6xSfE2Uf36P7sj6HlxZhzLsfUeYyf9NCHc/kZh+72SVQp/jPT7Vwx/k+P7voc1HtYE0gGRhnDvMh.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "aPcTSFH4b0r/tYM92pfj4AZSjfAWtE6sC02U4nuefoM+ueVibTbwlVmzgzffuhi9Hfd3lKSGqfs24NrdXRfNzhDCfD6WLWdn3YHwgF2Tta39u7ecJllC8PuORIgQ64yp") "<4A35C275-51AB-469C-BB0B-B21B43CCCCCD>" NIL "BASE64" 28036 NIL ("INLINE" ("FILENAME" {4166}\#r
                    kWiBWrpfOaX1TR+nk0REeTrcnFGEJq/l0aonrfgwIr6wIS06W6zFKmbbToYlD/bs/lpeD4urYdLN+fzS8XzF54J7SNWf2RlT6CrnjpMQXT9UoL6rQ32zi28BpIGiOlsFhivgZZnlnE7eCp+OXVI8/qAtaskCB4gwYx7uZrQYZgDVE+igNnEGsRcBHHNMhhw317FJ0F+M6L/T9AC0hUw0fTHQayUbs4F4EZYn7fUl5NIETpZSOd63VXJf8j608ThJv2tI+68sGacwZAC/+OFd0qr1ajCkY2De1hLGbSOvdajiq18ER3Kaxuh4nqzvgfbCnq1Z9WCnbJ+jc3NHdqZ42tCPlEZk2lisQa0n+2sfHjJyU1l1HfRFQGE3+Zi3PqjRyqZ2iSR5DS84XeBTB79XweDtBdAesQ9bASwR/2ybUF1LJ+xLRvybBpp+FTgX6vF6oVUiJ7auDE90aNGo6mC7VEYowL6kdXUNP/WgCDYkiWXSK2k1FQPkOLNPfT1KW0B0b8yldrnQSNAKC2TSWwKgnA2GcLUBuorl0c2HQL0u9XSpzPkZMoM+Ngy76wYiAt7er0JtI1PSnf3j36+jbnOgB1Hm2XigPLwQ0mKh28lE5RgDxytAM4pM6obnFRIpCLRHQuaTFEnWKxjY0GnGp9ncKEGj/qhdwsxtTg2a0Dery1W9EC7Q3PS7VOK/7DJDzWR0nwoNjo9VGBL7ifmEjLlvFBPy3Z0Kt7fvYDaNhcAEHqPNWE1sTrcUfXXtMbBxpeSpWl/fQaO6O7rjhJx0wHb3Wef3DIybQfJjQqLlEGwD69PixTmv/h5jTgcdfX3O/2Xx2BG6qjBJv+bcCg27zaJaa9ZMFaRJw4PEi8fmUxjMIwaBbE6njMRuHm/FwYtiaN5WFzS/S1SHTvBkU1R80jVqmblFVDb0dVZPfUUg4wUQEyDXmBDk3fbw69Ow/YMat8b7zp3THQCC2XCyUOFXK95M8nR+498anb+Pojmj97o//THjcNYx3EpfU3N8ghgXhQv42sGouoeWNJnj6EHbesi7uwh69ji5aMCJtBub7BFyjDO9/6NdoIabsfoBzEFA+6Xim2ba686AYIsGKid3jsD4ks6lAssMqlc9tQgXjtPtH3eZBvALpO0F7hZiMOvGz0U2VmQIbfFicyFRxA6dtHWSoAYdzo2I2iFO/gxbGe/N6cxKUAZCBn3/329arqWBgVxFM5IcGhKeyWNV0ij/Y6jcKKAFgy4j1QYjkNOPd55rZAl5CQv9G9GOuXiyaKy8RKyfWuXOm+4CzeG/K6iLYwb95Rhw78M+OsRAQzOaHt9ah3JJ78kshtMhWZvSaUr0AbAwuwTvv2B9B0XXn3Pt1Fsf1dNCAhghz//j8wLdN9tAugDSSY4OcBUNhoCAC9X1vEsZbXIQPTtpmEiM0C7s4TjPnmI3G0l071+Xt2moo5SdCldPH0JIJjv2rWNfcCipR5l+RbU6uME0GgDgYC3Txvno7eXyt9pZ+Z+5Q8Bc4J2VFTwQjXa8Ge0ZAdFkbjJOfGJeHgiXw36wV9FgjCd4DblvodeCzyuVHRcysxE8oVRUYCMtapn2oMd6imrLUBraPfiWlXg/aBxgalRXzMjFUVuruzSdxOEwTqplCOGInO6/viUCRbMPDZJd+5X7PdnLpUEtMYOWiKvHGL6hz6mwa1fMqKYNSNUXF3Z9EZgyYRVZUtcpAfwbA31FVHjrMyzgf7WObVHNoqoxFO6c1gptrkAzTBNh2v5h/feUlx4SBGyKMXbe5RrdjcmNmXRGKNlH/weOcfwRc7itn2Rf7xfQcOGo02I7E3K1YEgh/OObxpjwXh+/LWS1DnwpSFu6KmIjQQM1kKLhimA0VwR59bF6VPcQjv8e6+uZ/5k5J9ULgPs8yfdfMGgGWeOKZgSH0GWh0T04wVYfALgZChRbqBm4mZ5umf8FWW/5A10SFF/HyN9njEYI3f/VhmH7xMlDHAIqxpfGjXK6TKMyKOXpJNs1dwXmiIgUWtJeJeAiaKSbLBRDtamWjEMbjcasD0+AHpXvArRVSoNiflrvgVbAIWeJqeX6dL73wz7SD+NYj/cP1GyJ1xDmxXdaBCjqPb/t57gJptYJIk/WynRuKJQ6KMasx0Rf4RFxZjDlIOAckt/aYuXjQIOOvS2mBbXT41EpNGUKUuEguWHCl74br4occFqGMh2J0OW2oM8z9agIFRqEegT7cYOtGH6YfTzOgsF/d5QdxtzsuoOZu+tGoICW9QZDW0NdQKnwOvuHHv8MeXYxaIk4smQwJBHphtGZxtrlrCnbIev29BoaVHGhvcfm48mVxO3zMYDOLLvaqPknO5/ZZEUkDj7CLbjclMfkwbItBrL3UMXNvkvgxTuVtz7Ccr7pIfljk2sQuWrQUDLCxeK78HQUX/Z1Daznv7AgvCQOTShs9nZHuPTCmdKIDCWNDyZfJFBtLd1vqxjBvnYUjWMCDLKhxNmFENGntszuIQ/5bwgDRhQz8irV0R9/BdaLf4Um5GOhxCShW0ESxSEcNp5wMW4lhV7cZ2GbtdUuJ0Wp8eXfrJQbC/RoT8w7NWhpLB02o6XgvBrsNAgExnjMnV2+wmJx5lzgyRhgYt72KK1+i+NOEGyKy+JiNvKWWlJc6OI3n+BfWrXxLpS8z6bmZ78HHYQbPa1fHB2Y7LDncTetvRS0b+rjc6ITVTQF6gVNEhvVXexTA4Hb1oTBJyren4ZdxnW/xa9WBY/sqdu/eeLPkvmP2XBWuJ0H+NzfCwlpBz/z7FmE9m8U2ZQ9sZjv1fO/hdA9qXGI3FsNRJvYM8qZgQ3ZKGe2GWtd1rR+8tgCVSbcoKfE9vSBxyvBgxFl4CDA3UZpiJ728V0IV6TcBih/is8cEArEHIfvfBVwxsY+ulzA2MoMG1c2YWIIBfpwVZjBR81kyiFnfQf/O5GMpCJQXjpyf0ALlTcJGmyk1BTlToTbZDJapZbCOWprBHzlvsZfCc+Q5v0J/F4/oF7rBPqCkZNHdhiFgcG6g0V41qCli2AIFAiihYpdWNorfoAT0lrVdAsg+/8ba/wkmxnSw56tLenIN++6g+gD9ouaW/H4TTvZG7O5luHpUSA9bEfocCYMObhSf+rxHeCe2Qy4LEuErsGaltRcAjm3OWUioCp+lR1dwNr+OAjyXuut34YF+TpKGnOxZhLbqwY/H3yEvvshybW0jren3fqKqSBDETgMt25pFKR/EuzyBVsG3fjlHl/YM0MmtRcshD0716rlQbFHu6e4zSq2ifWeyUxZOnmAJTwWS9/YbK10g7AQ3xBY83qzKOvWaBDWlhU5WNa7VKEbOxi5yDUUFe+T1CRdfEpT6UsgIHedBtFmc2AZF787Qc4voVkmAklsIIrZe/TZ81mWVbuGyeKlxjMAkCHEMkvtfx2P7Lfn12Y1Bdx2GkVU0UhNo0Ze6dq+7kSphPCaoYE5tnKRTF6GQftl9C6c7mmmYGK4/BIHgBGy4bFLd5+avcqCzBwKePK/ZPF3E3pllH/+q2KWFuxzhybmWk2KerVdA0ikVkWNSW2/gpMTugSBpEgiyUfyvbSMYtUcog/LCAeR2pCcvNK97CFry/LXu+PCf87ySa8wDCvMMu/2dvGOfyftkhaup03e7beCzDq0O600PJE3ShbUIkcsjzcIN3dZvxPFdgIcKWTFgG2O4Lqqp9OgKrzSeov3kq9eC14XQ6eXPuJtdDYhMztcv0MN2d04woy4sb6L/ZMvuu9Tmy/TvEqm1/F0ZDKmpVktdb4+nN65v35tGE/t2LbKWXBcxu42gjzMwif4XhEtQBxHh4iNrMcTThcnp+2pvCYrLa2DngleBM4udAoRCe1F4svIE00TTivD6f+76VHoAdLnNLxOppn9DJErZlJ6riUyyuwbA94Qkg3tSXL2gXqKNZjg8zFGxi2nEqNV/UMbqSA93gPHkr+plDQlObpFuktZf9MKptDGXiLxBouYenPrZv7TyA85Czyc1CULnu1mcTJEEHsX+7msujJ9niBRBR2v1ncFam/y/kh31iYarZM9x+mYjughVplLXuZoRevSPNj8A7Eugo72XIMGhQmr+Rwj1x2jdJPHfrSGVaRylFa21GRC6CmkdFnf9Ykb0jqOizbKNyqBEaCxu8X3XWWzi/SksWGNU8ayuGm3nesLW7.png "FILENAME" "xJHLCERShdPBs3VnxQNfJ3nkq/BbyAiG7I9iASfNj56Tq21I0bolNt0jT6AGJkqvTGHkSAsAke1nN7aK1fn52lzhDDn5/ETSiNxeehmYkpDkslNK9ir6FAoXrAShX1Q9ePA0zzPLFUToUJrGo8QMmxF7d1XZkPRMa549tNfZmAoZauillxHK8zri5K+dw7F3Nh/KdTjfuYSytsv7qaKIAFked6h6gdrdbgXUUqJcRqPCHobd4dr5qh6mpqOi7zxP")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "B9dU4LiDvACp1HRGbGKv9a.png") "<A3DAD1EE-2550-4A10-89EE-60F18BCB02D3>" NIL "BASE64" 128886 NIL ("INLINE" ("FILENAME" "aQdlMfqCnnJ3NIEo4QaAtx.png")) NIL NIL) "RELATED" ("BOUNDARY" "Boundary_(ID_5at2F8cNBkCvhUaps4Ptr5)" "TYPE" "text/html") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Boundary_(ID_SvTb2C5OOHDZaweR3sETH+)") NIL NIL NIL))
                    """#,
                expected: [
                    .response(.fetch(.start(617_85))),
                    .response(.fetch(.simpleAttribute(.uid(127_139)))),
                    .response(.fetch(.simpleAttribute(.rfc822Size(1_008_880)))),
                    .response(.fetch(.simpleAttribute(.body(.invalid, hasExtensionData: true)))),
                    .response(.fetch(.finish)),
                ]
            ),
        ]
    )
    fileprivate func parseResponseStream(
        fixture: ResponseStreamFixture
    ) {
        var buffer = ByteBuffer(string: fixture.input + "\r\n")
        var results = [ResponseOrContinuationRequest]()
        var parser = ResponseParser()
        while buffer.readableBytes > 0 {
            #expect(throws: Never.self) {
                guard
                    let resp = try parser.parseResponseStream(buffer: &buffer)
                else {
                    Issue.record()
                    return
                }
                results.append(resp)
            }
        }
        #expect(results == fixture.expected)
        #expect(buffer.readableBytes == 0)
    }
}

// MARK: -

private struct ResponseStreamFixture: CustomTestArgumentEncodable, CustomTestStringConvertible {
    var input: String
    var expected: [ResponseOrContinuationRequest]

    func encodeTestArgument(to encoder: some Encoder) throws {
        try input.encode(to: encoder)
    }

    var testDescription: String { input.mappingControlPictures() }
}

// MARK: - ENVELOPE group markers (#859)

extension ResponseParserTests {
    @Test("malformed ENVELOPE groups: envelope normalized, stream in sync", arguments: EnvelopeStreamFixture.all)
    fileprivate func envelopeGroupsInStream(_ fixture: EnvelopeStreamFixture) throws {
        let parsed = try Self.parseStream(fixture.bytes, delivery: .singleShot)
        #expect(parsed.unconsumedBytes == 0)
        #expect(parsed.responses.first == .response(.fetch(.start(fixture.sequenceNumber))))
        #expect(Array(parsed.responses.suffix(2)) == [.response(.fetch(.finish)), Self.taggedOK])
        #expect(Self.envelopes(in: parsed.responses) == fixture.expectedEnvelopes)
    }

    @Test("byte-at-a-time equals single-shot", arguments: EnvelopeStreamFixture.all)
    fileprivate func envelopeGroupsByteAtATime(_ fixture: EnvelopeStreamFixture) throws {
        let singleShot = try Self.parseStream(fixture.bytes, delivery: .singleShot)
        let chunked = try Self.parseStream(fixture.bytes, delivery: .byteAtATime)
        #expect(chunked == singleShot)
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    /// Issue #859 reproducer. A regression crashes the child process, not the runner.
    @Test("deep ENVELOPE groups parse and release on a small stack") func deepEnvelopeGroups() async {
        await #expect(processExitsWith: .success) {
            let summary = await DeepEnvelope.onPinnedStack {
                let parsed = try! ResponseParserTests.parseStream(
                    DeepEnvelope.response,
                    delivery: .singleShot,
                    options: DeepEnvelope.parserOptions
                )
                return DeepEnvelope.Summary(parsed)
            }
            precondition(summary == DeepEnvelope.expectedSummary, "\(summary)")
        }
    }

    /// Deep input in seeded random chunks ≥ 1 KiB (byte-at-a-time would re-parse ~340 KB per byte).
    @Test("deep ENVELOPE groups: random chunks equal single-shot") func deepEnvelopeGroupsChunked() async {
        await #expect(processExitsWith: .success) {
            let equal = await DeepEnvelope.onPinnedStack {
                let singleShot = try! ResponseParserTests.parseStream(
                    DeepEnvelope.response,
                    delivery: .singleShot,
                    options: DeepEnvelope.parserOptions
                )
                let chunked = try! ResponseParserTests.parseStream(
                    DeepEnvelope.response,
                    delivery: .randomChunks(seed: DeepEnvelope.chunkSeed, sizes: DeepEnvelope.chunkSizes),
                    options: DeepEnvelope.parserOptions
                )
                return chunked == singleShot
            }
            precondition(equal)
        }
    }
    #endif

    /// In-process on every platform: exercises each recursive path the issue names, on a 512 KiB stack.
    /// A regression kills the runner, so this lands with the fix only.
    @Test("deep ENVELOPE groups: compare, hash, encode, describe, release on a small stack")
    func deepEnvelopeGroupsInProcess() async throws {
        let outcome = await DeepEnvelope.onPinnedStack {
            Result { try DeepEnvelope.Exercised.run() }
        }
        let exercised = try outcome.get()
        #expect(exercised.summary == DeepEnvelope.expectedSummary)
        #expect(exercised.parsesEqual)
        #expect(exercised.hashesEqual)
        #expect(exercised.encodedByteCount == DeepEnvelope.expectedEncodedByteCount)
        #expect(exercised.describedNonEmpty)
    }
}

// MARK: - Helpers

extension ResponseParserTests {
    fileprivate static let taggedOK = ResponseOrContinuationRequest.response(
        .tagged(.init(tag: "A1", state: .ok(.init(text: "done"))))
    )

    /// Feeds `input` in chunks; after each chunk parses until the parser needs more bytes.
    fileprivate static func parseStream(
        _ input: ByteBuffer,
        delivery: Delivery,
        options: ResponseParser.Options = .init()
    ) throws -> ParsedStream {
        var parser = ResponseParser(options: options)
        var remaining = input
        var buffer = ByteBuffer()
        var responses: [ResponseOrContinuationRequest] = []
        for size in delivery.chunkSizes(total: input.readableBytes) {
            var chunk = remaining.readSlice(length: min(size, remaining.readableBytes))!
            buffer.writeBuffer(&chunk)
            while let response = try parser.parseResponseStream(buffer: &buffer) {
                responses.append(response)
            }
        }
        return ParsedStream(responses: responses, unconsumedBytes: buffer.readableBytes)
    }

    /// Top-level envelopes and those of nested `message/rfc822` parts, in order.
    fileprivate static func envelopes(in responses: [ResponseOrContinuationRequest]) -> [Envelope] {
        var result: [Envelope] = []
        for case .response(.fetch(.simpleAttribute(let attribute))) in responses {
            switch attribute {
            case .envelope(let envelope):
                result.append(envelope)
            case .body(.valid(let body), hasExtensionData: _):
                result += envelopes(in: body)
            default:
                continue
            }
        }
        return result
    }

    private static func envelopes(in body: BodyStructure) -> [Envelope] {
        var pending = [body]
        var result: [Envelope] = []
        while let next = pending.popLast() {
            switch next {
            case .multipart(let multipart):
                pending.append(contentsOf: multipart.parts.reversed())
            case .singlepart(let part):
                guard case .message(let message) = part.kind else { continue }
                result.append(message.envelope)
                pending.append(message.body)
            }
        }
        return result
    }
}

private struct ParsedStream: Equatable {
    var responses: [ResponseOrContinuationRequest]
    var unconsumedBytes: Int
}

private enum Delivery {
    case singleShot
    /// Small fixtures only: the parser re-parses the whole response per call.
    case byteAtATime
    case randomChunks(seed: UInt64, sizes: ClosedRange<Int>)

    func chunkSizes(total: Int) -> [Int] {
        switch self {
        case .singleShot:
            return [total]
        case .byteAtATime:
            return Array(repeating: 1, count: total)
        case .randomChunks(let seed, let sizes):
            var rng = SplitMix64(seed: seed)
            var result: [Int] = []
            var covered = 0
            while covered < total {
                let size = Int.random(in: sizes, using: &rng)
                result.append(size)
                covered += size
            }
            return result
        }
    }
}

/// Issue #859 reproducer: `depth` nested group starts, one address, `depth` end markers (~340 KB).
private enum DeepEnvelope {
    static let depth = 10_000
    static let pinnedStackSize = 512 * 1024
    static let parserOptions = ResponseParser.Options(bufferLimit: 1 << 20)
    static let chunkSeed: UInt64 = 859
    static let chunkSizes = 1024...8192

    static let start = #"(NIL NIL "g" NIL)"#
    static let member = #"(NIL NIL "x" "example.com")"#
    static let end = "(NIL NIL NIL NIL)"

    static var response: ByteBuffer {
        let from = String(repeating: start, count: depth) + member + String(repeating: end, count: depth)
        return ByteBuffer(string: "* 1 FETCH (ENVELOPE (NIL NIL (\(from)) NIL NIL NIL NIL NIL NIL NIL))\r\nA1 OK done\r\n")
    }

    /// Normalized: `depth - 1` demoted starts, then the innermost group with its member.
    static let expectedSummary = Summary(fromCount: depth, maximumGroupDepth: 1, responseCount: 4, unconsumedBytes: 0)

    /// Encoder output for the normalized From list: every start (demoted or bracketing), member, one end.
    static let expectedEncodedByteCount = depth * start.utf8.count + member.utf8.count + end.utf8.count

    /// Computed iteratively, so it is safe on any tree.
    struct Summary: Equatable, Sendable {
        var fromCount: Int
        var maximumGroupDepth: Int
        var responseCount: Int
        var unconsumedBytes: Int

        init(fromCount: Int, maximumGroupDepth: Int, responseCount: Int, unconsumedBytes: Int) {
            self.fromCount = fromCount
            self.maximumGroupDepth = maximumGroupDepth
            self.responseCount = responseCount
            self.unconsumedBytes = unconsumedBytes
        }

        init(_ parsed: ParsedStream) {
            let from = ResponseParserTests.envelopes(in: parsed.responses).first?.from ?? []
            var pending: [(elements: [EmailAddressListElement], depth: Int)] = [(from, 0)]
            var maximum = 0
            while let (list, depth) = pending.popLast() {
                maximum = max(maximum, depth)
                for case .group(let group) in list {
                    pending.append((group.children, depth + 1))
                }
            }
            self.init(
                fromCount: from.count,
                maximumGroupDepth: maximum,
                responseCount: parsed.responses.count,
                unconsumedBytes: parsed.unconsumedBytes
            )
        }
    }

    /// Results of `==`, `hashValue`, encode and `String(describing:)` on two independent parses.
    struct Exercised: Sendable {
        var summary: Summary
        var parsesEqual: Bool
        var hashesEqual: Bool
        var encodedByteCount: Int
        var describedNonEmpty: Bool

        /// Call on the pinned stack: both trees are built and released there.
        static func run() throws -> Exercised {
            // Two parses, so `==` can't short-circuit on shared storage.
            let first = try ResponseParserTests.parseStream(response, delivery: .singleShot, options: parserOptions)
            let second = try ResponseParserTests.parseStream(response, delivery: .singleShot, options: parserOptions)
            let firstFrom = ResponseParserTests.envelopes(in: first.responses).first?.from ?? []
            let secondFrom = ResponseParserTests.envelopes(in: second.responses).first?.from ?? []

            var encoder = EncodeBuffer.serverEncodeBuffer(
                buffer: ByteBufferAllocator().buffer(capacity: 1 << 20),
                options: ResponseEncodingOptions(),
                loggingMode: false
            )
            let encodedByteCount = firstFrom.reduce(0) { $0 + encoder.writeEmailAddressOrGroup($1) }

            return Exercised(
                summary: Summary(first),
                parsesEqual: first == second,
                hashesEqual: firstFrom.hashValue == secondFrom.hashValue,
                encodedByteCount: encodedByteCount,
                // From list: Mirror (recursive); response: `debugDescription` (encoder).
                describedNonEmpty: !String(describing: firstFrom).isEmpty && !String(describing: first).isEmpty
            )
        }
    }

    /// Runs `body` on a thread with a fixed 512 KiB stack; locals are released there too.
    static func onPinnedStack<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            let thread = Thread {
                continuation.resume(returning: body())
            }
            thread.stackSize = pinnedStackSize
            thread.start()
        }
    }
}

// MARK: - Fixtures

private struct EnvelopeStreamFixture: Sendable, CustomTestStringConvertible {
    var name: String
    var sequenceNumber: SequenceNumber
    /// One FETCH response; `A1 OK done` is appended.
    var response: String
    var expectedEnvelopes: [Envelope]

    var testDescription: String { name }

    var bytes: ByteBuffer {
        ByteBuffer(string: response + "\r\nA1 OK done\r\n")
    }
}

extension EnvelopeStreamFixture {
    static let all: [EnvelopeStreamFixture] = [
        // Cyrus 3.10.2, msg 07, `To: alice@example.com;`: stray end dropped.
        EnvelopeStreamFixture(
            name: "Cyrus 07 stray end",
            sequenceNumber: 7,
            response:
                #"* 7 FETCH (UID 7 ENVELOPE ("Mon, 12 Oct 2026 10:00:00 +0000" "07-stray-end" ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "alice" "example.com")(NIL NIL NIL NIL)) NIL NIL NIL "<07-stray-end@example.com>") BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 23 1 NIL NIL NIL NIL))"#,
            expectedEnvelopes: [
                .captured("07-stray-end", to: [.singleAddress(.address("alice", "example.com"))])
            ]
        ),
        // Cyrus 3.10.2, msg 35, `To: team@x: alice@example.com;`: stray end dropped.
        EnvelopeStreamFixture(
            name: "Cyrus 35 stray end",
            sequenceNumber: 35,
            response:
                #"* 35 FETCH (UID 35 ENVELOPE ("Mon, 12 Oct 2026 10:00:00 +0000" "35-group-name-with-at" ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "team" "x:alice@example.com")(NIL NIL NIL NIL)) NIL NIL NIL "<35-group-name-with-at@example.com>") BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 32 1 NIL NIL NIL NIL))"#,
            expectedEnvelopes: [
                .captured("35-group-name-with-at", to: [.singleAddress(.address("team", "x:alice@example.com"))])
            ]
        ),
        // Cyrus 3.10.2, msg 03, `To: A: B: x@example.com;;`: balanced, unchanged.
        EnvelopeStreamFixture(
            name: "Cyrus 03 nested header",
            sequenceNumber: 3,
            response:
                #"* 3 FETCH (UID 3 ENVELOPE ("Mon, 12 Oct 2026 10:00:00 +0000" "03-nested" ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "A" NIL)(NIL NIL "B: x" "example.com")(NIL NIL NIL NIL)(NIL NIL ";" "unspecified-domain")) NIL NIL NIL "<03-nested@example.com>") BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 20 1 NIL NIL NIL NIL))"#,
            expectedEnvelopes: [.captured("03-nested", to: .cyrusNested)]
        ),
        // Dovecot 2.4.3, msg 03, `To: A: B: x@example.com;;`: balanced, unchanged.
        EnvelopeStreamFixture(
            name: "Dovecot 03 nested header",
            sequenceNumber: 3,
            response:
                #"* 3 FETCH (UID 3 ENVELOPE ("Mon, 12 Oct 2026 10:00:00 +0000" "03-nested" ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "A" NIL)(NIL NIL "B" "MISSING_DOMAIN")(NIL NIL NIL NIL)) NIL NIL NIL "<03-nested@example.com>") BODYSTRUCTURE ("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 20 1 NIL NIL NIL NIL))"#,
            expectedEnvelopes: [
                .captured(
                    "03-nested",
                    to: [.group(.init(groupName: "A", sourceRoot: nil, children: [.singleAddress(.address("B", "MISSING_DOMAIN"))]))]
                )
            ]
        ),
        // Dovecot 2.4.3, msg 01: well-formed group (control).
        EnvelopeStreamFixture(
            name: "Dovecot 01 well-formed group",
            sequenceNumber: 1,
            response:
                #"* 1 FETCH (UID 1 ENVELOPE ("Mon, 12 Oct 2026 10:00:00 +0000" "01-control-wellformed-group" ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL "bob" "example.com")(NIL NIL NIL NIL)) NIL NIL NIL "<01-control-wellformed-group@example.com>") BODYSTRUCTURE ("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 38 1 NIL NIL NIL NIL))"#,
            expectedEnvelopes: [
                .captured(
                    "01-control-wellformed-group",
                    to: [
                        .group(
                            .init(
                                groupName: "Team",
                                sourceRoot: nil,
                                children: [
                                    .singleAddress(.address("alice", "example.com")),
                                    .singleAddress(.address("bob", "example.com")),
                                ]
                            )
                        )
                    ]
                )
            ]
        ),
        // Cyrus 3.10.2, msg 18: groups in a nested `message/rfc822` envelope (control).
        EnvelopeStreamFixture(
            name: "Cyrus 18 message/rfc822",
            sequenceNumber: 18,
            response:
                #"* 18 FETCH (UID 18 ENVELOPE ("Mon, 12 Oct 2026 10:00:00 +0000" "18-rfc822-attachment-nested" ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "sender" "example.com")) ((NIL NIL "outer" "example.com")) NIL NIL NIL "<18-rfc822-attachment-nested@example.com>") BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 11 0 NIL NIL NIL NIL)("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 250 ("Mon, 12 Oct 2026 10:00:00 +0000" "inner" ((NIL NIL "inner" "example.com")) ((NIL NIL "inner" "example.com")) ((NIL NIL "inner" "example.com")) ((NIL NIL "A" NIL)(NIL NIL "B: x" "example.com")(NIL NIL NIL NIL)(NIL NIL ";" "unspecified-domain")) ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")(NIL NIL NIL NIL)) NIL NIL "<inner-18@example.com>") ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 13 1 NIL NIL NIL NIL) 10 NIL NIL NIL NIL) "MIXED" ("BOUNDARY" "BOUNDARY859") NIL NIL NIL))"#,
            expectedEnvelopes: [
                .captured("18-rfc822-attachment-nested", to: [.singleAddress(.address("outer", "example.com"))]),
                Envelope(
                    date: .capturedDate,
                    subject: "inner",
                    from: [.singleAddress(.address("inner", "example.com"))],
                    sender: [.singleAddress(.address("inner", "example.com"))],
                    reply: [.singleAddress(.address("inner", "example.com"))],
                    to: .cyrusNested,
                    cc: [.group(.init(groupName: "Team", sourceRoot: nil, children: [.singleAddress(.address("alice", "example.com"))]))],
                    bcc: [],
                    inReplyTo: nil,
                    messageID: "<inner-18@example.com>"
                ),
            ]
        ),
        // Synthetic malicious-server shapes, as FETCH ENVELOPE From.
        EnvelopeStreamFixture(
            name: "synthetic nested",
            sequenceNumber: 1,
            response:
                #"* 1 FETCH (ENVELOPE (NIL NIL ((NIL NIL "A" NIL)(NIL NIL "B" NIL)(NIL NIL "x" "example.com")(NIL NIL NIL NIL)(NIL NIL NIL NIL)) NIL NIL NIL NIL NIL NIL NIL))"#,
            expectedEnvelopes: [
                .fromOnly([
                    .singleAddress(.groupStart("A")),
                    .group(.init(groupName: "B", sourceRoot: nil, children: [.singleAddress(.address("x", "example.com"))])),
                ])
            ]
        ),
        EnvelopeStreamFixture(
            name: "synthetic unclosed",
            sequenceNumber: 1,
            response:
                #"* 1 FETCH (ENVELOPE (NIL NIL ((NIL NIL "Team" NIL)(NIL NIL "alice" "example.com")) NIL NIL NIL NIL NIL NIL NIL))"#,
            expectedEnvelopes: [
                .fromOnly([.singleAddress(.groupStart("Team")), .singleAddress(.address("alice", "example.com"))])
            ]
        ),
        EnvelopeStreamFixture(
            name: "synthetic host-NIL addresses",
            sequenceNumber: 1,
            response:
                #"* 1 FETCH (ENVELOPE (NIL NIL ((NIL NIL "root" NIL)(NIL NIL "admin" NIL)) NIL NIL NIL NIL NIL NIL NIL))"#,
            expectedEnvelopes: [.fromOnly([.singleAddress(.groupStart("root")), .singleAddress(.groupStart("admin"))])]
        ),
        // Synthetic: malformed From (nested start, stray end) in a `message/rfc822` part's envelope.
        EnvelopeStreamFixture(
            name: "synthetic message/rfc822 malformed From",
            sequenceNumber: 2,
            response:
                #"* 2 FETCH (BODYSTRUCTURE ("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 250 (NIL NIL ((NIL NIL "A" NIL)(NIL NIL "B" NIL)(NIL NIL "x" "example.com")(NIL NIL NIL NIL)(NIL NIL NIL NIL)) NIL NIL NIL NIL NIL NIL NIL) ("TEXT" "PLAIN" ("CHARSET" "us-ascii") NIL NIL "7BIT" 13 1) 10))"#,
            expectedEnvelopes: [
                .fromOnly([
                    .singleAddress(.groupStart("A")),
                    .group(.init(groupName: "B", sourceRoot: nil, children: [.singleAddress(.address("x", "example.com"))])),
                ])
            ]
        ),
    ]
}

extension Array where Element == EmailAddressListElement {
    /// What Cyrus sends for `To: A: B: x@example.com;;` (msgs 03, 18).
    fileprivate static let cyrusNested: Self = [
        .group(.init(groupName: "A", sourceRoot: nil, children: [.singleAddress(.address("B: x", "example.com"))])),
        .singleAddress(.address(";", "unspecified-domain")),
    ]
}

extension InternetMessageDate {
    fileprivate static let capturedDate: Self = "Mon, 12 Oct 2026 10:00:00 +0000"
}

extension Envelope {
    /// Envelope of a captured message: sender@example.com in From/Sender/Reply-To, subject = message ID stem.
    fileprivate static func captured(_ subject: String, to: [EmailAddressListElement]) -> Envelope {
        let sender: [EmailAddressListElement] = [.singleAddress(.address("sender", "example.com"))]
        return Envelope(
            date: .capturedDate,
            subject: ByteBuffer(string: subject),
            from: sender,
            sender: sender,
            reply: sender,
            to: to,
            cc: [],
            bcc: [],
            inReplyTo: nil,
            messageID: MessageID("<\(subject)@example.com>")
        )
    }

    fileprivate static func fromOnly(_ from: [EmailAddressListElement]) -> Envelope {
        Envelope(
            date: nil,
            subject: nil,
            from: from,
            sender: [],
            reply: [],
            to: [],
            cc: [],
            bcc: [],
            inReplyTo: nil,
            messageID: nil
        )
    }
}

extension EmailAddress {
    fileprivate static func address(_ mailbox: ByteBuffer, _ host: ByteBuffer) -> EmailAddress {
        .init(personName: nil, sourceRoot: nil, mailbox: mailbox, host: host)
    }

    /// RFC 3501 §7.4.2 group start marker (host NIL).
    fileprivate static func groupStart(_ name: ByteBuffer) -> EmailAddress {
        .init(personName: nil, sourceRoot: nil, mailbox: name, host: nil)
    }
}
