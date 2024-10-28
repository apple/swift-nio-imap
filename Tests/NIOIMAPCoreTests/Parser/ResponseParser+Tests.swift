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

class ResponseParser_Tests: XCTestCase {}

// MARK: - init

extension ResponseParser_Tests {
    func testInit_defaultBufferSize() {
        let parser = CommandParser()
        XCTAssertEqual(parser.bufferLimit, 8_192)
    }

    func testInit_customBufferSize() {
        let parser = CommandParser(bufferLimit: 80_000)
        XCTAssertEqual(parser.bufferLimit, 80_000)
    }
}

// MARK: - parseResponseStream

extension ResponseParser_Tests {
    func testAttemptToStreamBytesFromEmptyBuffer() {
        var parser = ResponseParser()
        var buffer: ByteBuffer = ""

        // set up getting ready to stream a response
        buffer = "* 1 FETCH (BODY[TEXT]<4> {10}\r\n"
        XCTAssertNotNil(XCTAssertNoThrow(try parser.parseResponseStream(buffer: &buffer)))
        XCTAssertNotNil(XCTAssertNoThrow(try parser.parseResponseStream(buffer: &buffer)))

        // now send an empty buffer for parsing, expect nil
        buffer = ""
        XCTAssertNoThrow(XCTAssertNil(try parser.parseResponseStream(buffer: &buffer)))
        XCTAssertNoThrow(XCTAssertNil(try parser.parseResponseStream(buffer: &buffer)))
        XCTAssertNoThrow(XCTAssertNil(try parser.parseResponseStream(buffer: &buffer)))
        XCTAssertNoThrow(XCTAssertNil(try parser.parseResponseStream(buffer: &buffer)))

        // send some bytes to make sure it's worked
        buffer = "0123456789"
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.streamingBytes("0123456789")))
        )
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingEnd)))
    }

    func testParseResponseStream() {
        let inputs: [(String, [ResponseOrContinuationRequest], UInt)] = [
            ("+ OK Continue", [.continuationRequest(.responseText(.init(text: "OK Continue")))], #line),
            (
                "1 OK NOOP Completed", [.response(.tagged(.init(tag: "1", state: .ok(.init(text: "NOOP Completed")))))],
                #line
            ),
            (
                "* 999 FETCH (FLAGS (\\Seen))",
                [
                    .response(.fetch(.start(999))),
                    .response(.fetch(.simpleAttribute(.flags([.seen])))),
                    .response(.fetch(.finish)),
                ],
                #line
            ),
            (
                #"* 12190 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 12194 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 3034 50 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "_____5C088583DDA30A778CEA0F5BFE2856D1") NIL NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 12180 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 221 5 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "7BIT" 2075 20 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c" "CHARSET" "UTF-8") NIL NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 12182 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 239844 4078 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 239844 4078 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "===============8996999810533184102==") NIL NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 12183 FETCH (BODYSTRUCTURE ("TEXT" "HTML" NIL NIL NIL "BINARY" 28803 603 NIL NIL NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 12184 FETCH (BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "utf-8") "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>" NIL "BASE64" 2340 30 NIL NIL ("EN-US") NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 12187 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 6990 170 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 18865 274 NIL NIL NIL NIL)("APPLICATION" "OCTET-STREAM" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.key") NIL NIL "BASE64" 4876604 NIL ("ATTACHMENT" ("FILENAME" "Whiteboard on Webex.key")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 1143 17 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.pdf") NIL NIL "BASE64" 1191444 NIL ("INLINE" ("FILENAME" "Whiteboard on Webex.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 2217 32 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0666" "NAME" "Resume.pdf") NIL NIL "BASE64" 217550 NIL ("INLINE" ("FILENAME" "Resume.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 4450 62 NIL NIL NIL NIL) "MIXED" ("BOUNDARY" "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F") NIL NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 53 FETCH (BODYSTRUCTURE (("TEXT" "HTML" NIL NIL NIL "7BIT" 151 0 NIL NIL NIL) "MIXED" ("BOUNDARY" "----=rfsewr") NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 433 FETCH (BODYSTRUCTURE (((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 710 20 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4323 42 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "4__=rtfgha") NIL NIL)("IMAGE" "JPEG" ("NAME" "bike.jpeg") "<2__=lgkfjr>" NIL "BASE64" 64 NIL ("INLINE" ("FILENAME" "bike.jpeg")) NIL) "RELATED" ("BOUNDARY" "0__=rtfgaa") NIL NIL)("APPLICATION" "PDF" ("NAME" "title.pdf") "<5__=jlgkfr>" NIL "BASE64" 333980 NIL ("ATTACHMENT" ("FILENAME" "list.pdf")) NIL) "MIXED" ("BOUNDARY" "1__=tfgrhs") NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                #"* 234 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 410 24 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 1407 30 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "hqjksdm1__=") NIL NIL)("IMAGE" "PNG" ("NAME" "screenshot.png") "<3__=f2fcxd>" NIL "BASE64" 40655 NIL ("INLINE" ("FILENAME" "screenshot.png")) NIL) "RELATED" ("BOUNDARY" "5__=hsdqjkm") NIL NIL))"#,
                [
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
                ],
                #line
            ),
            (
                "* 12183 FETCH (UID 2282556735 PREVIEW {3}\r\nabc FLAGS (\\Seen))",
                [
                    .response(.fetch(.start(12183))),
                    .response(.fetch(.simpleAttribute(.uid(2_282_556_735)))),
                    .response(.fetch(.simpleAttribute(.preview(.init("abc"))))),
                    .response(.fetch(.simpleAttribute(.flags([.seen])))),
                    .response(.fetch(.finish)),
                ],
                #line
            ),
            (
                #"""
                * 61785 FETCH (UID 127139 RFC822.SIZE 1008880 BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 50561 1112 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 546481 8065 NIL NIL NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "5mXzRqbGv/TuLF6tt8xeaTEK6jd/gBgAY3XUG85B9s62ixIvEnoCeXRBcG9wznRsUPSHerV324xgnpBSueR9s8BcGf+nkPfhtxxDnfuVrjJBpQSKj0lbPY/Npq+Ak7/f") "<2514DF6C-D2FA-46AD-B0DC-2CCF2358624A>" NIL "BASE64" 21258 NIL ("INLINE" ("FILENAME" "UesGpGJHsr20S9xoFoOnVOUe0xsqcOHcMUqZzJ8O0PhcZsBEUoMS9wmpnWyuGlTeypczpIqTpZknCdtg6iTESUOke7lUE/RZdi4hFTtD4GZpWGZm4CA5ApFjXmjw.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "6MEADWH7I2HpWPPz2K.png") "<9D94C1DE-808F-44E6-A4AB-AA97043B5899>" NIL "BASE64" 64938 NIL ("INLINE" ("FILENAME" "6MEADWH7I2HpWPPz2K.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "WE4fsw0y6p6V17F3UfrFhpYM1lrItLSgznkEBLLUWUUwk1Qu6NtkscCSp9KBr4qKUalGsfJL6ODQQzjMdocPuwK2LNIzp9o/gob97bIjURtGg/FoTMXwOCd2RzBRj/aA") "<BA1253E9-4D29-4DC2-AB7F-61E31D6983AC>" NIL "BASE64" 32806 NIL ("INLINE" ("FILENAME" "zQSAL4irVrBiICQ5gLC6yVGjmuviR4dpaL8j/H24kIezbAO4fnrtJxeBXcya/RmINP1Zi51W/30tEu3nlXdniYXzl4R5kC4jiD6gcwbyrKB8H/GyAAr8AV1OB8/XRV8F.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "uvlE2DBWSit0TrFrfgq02LlrISPRZUFYRD7myv32Or4OMTHKwby0k9riwJVm4N5z93SXzsHcj9Srj/cWIZuhDV95NPlfVZJbG1ukKwBGKajU7kGvjB+5IhyUy02y.png") "<840604E1-282C-424C-85E6-E9C31CA8D3E5>" NIL "BASE64" 122432 NIL ("INLINE" ("FILENAME" "PG+0O0vAYNGhK77Iy6EEDgJyLEKZ/WNlfHuVkdRU6lAz7+Xn6xSfE2Uf36P7sj6HlxZhzLsfUeYyf9NCHc/kZh+72SVQp/jPT7Vwx/k+P7voc1HtYE0gGRhnDvMh.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "aPcTSFH4b0r/tYM92pfj4AZSjfAWtE6sC02U4nuefoM+ueVibTbwlVmzgzffuhi9Hfd3lKSGqfs24NrdXRfNzhDCfD6WLWdn3YHwgF2Tta39u7ecJllC8PuORIgQ64yp") "<4A35C275-51AB-469C-BB0B-B21B43CCCCCD>" NIL "BASE64" 28036 NIL ("INLINE" ("FILENAME" {4166}\#r
                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.png "FILENAME" "xJHLCERShdPBs3VnxQNfJ3nkq/BbyAiG7I9iASfNj56Tq21I0bolNt0jT6AGJkqvTGHkSAsAke1nN7aK1fn52lzhDDn5/ETSiNxeehmYkpDkslNK9ir6FAoXrAShX1Q9ePA0zzPLFUToUJrGo8QMmxF7d1XZkPRMa549tNfZmAoZauillxHK8zri5K+dw7F3Nh/KdTjfuYSytsv7qaKIAFked6h6gdrdbgXUUqJcRqPCHobd4dr5qh6mpqOi7zxP")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "B9dU4LiDvACp1HRGbGKv9a.png") "<A3DAD1EE-2550-4A10-89EE-60F18BCB02D3>" NIL "BASE64" 128886 NIL ("INLINE" ("FILENAME" "aQdlMfqCnnJ3NIEo4QaAtx.png")) NIL NIL) "RELATED" ("BOUNDARY" "Boundary_(ID_5at2F8cNBkCvhUaps4Ptr5)" "TYPE" "text/html") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Boundary_(ID_SvTb2C5OOHDZaweR3sETH+)") NIL NIL NIL))
                """#,
                [
                    .response(.fetch(.start(617_85))),
                    .response(.fetch(.simpleAttribute(.uid(127_139)))),
                    .response(.fetch(.simpleAttribute(.rfc822Size(1_008_880)))),
                    .response(.fetch(.simpleAttribute(.body(.invalid, hasExtensionData: true)))),
                    .response(.fetch(.finish)),
                ],
                #line
            ),
        ]

        for (input, expected, line) in inputs {
            var buffer = ByteBuffer(string: input + "\r\n")
            var results = [ResponseOrContinuationRequest]()
            var parser = ResponseParser()
            while buffer.readableBytes > 0 {
                do {
                    guard let resp = try parser.parseResponseStream(buffer: &buffer) else {
                        XCTFail("", line: line)
                        return
                    }
                    results.append(resp)
                } catch {
                    XCTFail("\(error)", line: line)
                    return
                }
            }
            XCTAssertEqual(results, expected, line: line)
            XCTAssertEqual(buffer.readableBytes, 0)
        }
    }

    func testParseIncompleteInvalidBodyStructure() {
        //
        // When parsing an incomplete buffer, parseInvalidBody() will throw an
        // IncompleteMessage error. This needs to _not_ fail the parsing, but instead
        // bubble up to parseResponseStream() which will then wait for more data.
        //
        var buffer = ByteBuffer(
            string: #"""
                * 61785 FETCH (UID 127139 BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 71399 1519 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 659725 9831 NIL NIL NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "H9eubHenuyTiQAAAABJRU5ErkJggg==.png") "<5079C210-D42C-49F4-A942-2BA779C88A96>" NIL "BASE64" 104028 NIL ("INLINE" ("FILENAME" "H9eubHenuyTiQAAAABJRU5ErkJggg==.png")) NIL NIL)("IMAGE" "PNG" ("X-UNIX-MODE" "0666" "NAME" "IAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJNAKAQMdW8HsSSQgAQlIQAISkIAEJCABCUhAAhKQgAQkIAEJSEACEpCABCQgAQlIQAISkIAEJCABCUhAA") "<23E8CC74-836D-4B45-8B1E-1CF023182729>" NIL "BASE64" 55168 NIL ("INLINE" ("FILENAME" {4138}\#r\#naaaaaaaa
                """#
        )
        var parser = ResponseParser()
        XCTAssertEqual(
            try { () -> [ResponseOrContinuationRequest] in
                var results: [ResponseOrContinuationRequest] = []
                while buffer.readableBytes > 0 {
                    guard let resp = try parser.parseResponseStream(buffer: &buffer) else { break }
                    results.append(resp)
                }
                return results
            }(),
            [
                .response(.fetch(.start(617_85))),
                .response(.fetch(.simpleAttribute(.uid(127_139)))),
            ]
        )
    }

    func testAttributeLimit_failOnStreaming() {
        var parser = ResponseParser(bufferLimit: 1000, messageAttributeLimit: 3)
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 RFC822.TEXT {3}\r\n "

        // limit is 3, so let's parse the first 3
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.simpleAttribute(.flags([.seen]))))
        )
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.uid(1)))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.simpleAttribute(.rfc822Size(123))))
        )

        // the limit is 3, so the fourth should fail
        XCTAssertThrowsError(try parser.parseResponseStream(buffer: &buffer)) { e in
            XCTAssertTrue(e is ExceededMaximumMessageAttributesError)
        }
    }

    func testAttributeLimit_failOnSimple() {
        var parser = ResponseParser(bufferLimit: 1000, messageAttributeLimit: 3)
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 UID 2 "

        // limit is 3, so let's parse the first 3
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.simpleAttribute(.flags([.seen]))))
        )
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.uid(1)))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.simpleAttribute(.rfc822Size(123))))
        )

        // the limit is 3, so the fourth should fail
        XCTAssertThrowsError(try parser.parseResponseStream(buffer: &buffer)) { e in
            XCTAssertTrue(e is ExceededMaximumMessageAttributesError)
        }
    }

    func testRejectLargeBodies() {
        var parser = ResponseParser(bufferLimit: 1000, bodySizeLimit: 10)
        var buffer: ByteBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3)))
        )
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingBytes("123"))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingEnd)))

        XCTAssertThrowsError(try parser.parseResponseStream(buffer: &buffer)) { e in
            XCTAssertTrue(e is ExceededMaximumBodySizeError)
        }
    }

    func testParseNoStringCache() {
        var parser = ResponseParser(bufferLimit: 1000, bodySizeLimit: 10)
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen))\r\n"
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.simpleAttribute(.flags([.seen]))))
        )
    }

    // The flag "seen" should be given to our cache closure
    // which will replace it with "nees", and therefore our
    // parse result should contain the flag "nees".
    func testParseWithStringCache() {
        func testCache(string: String) -> String {
            XCTAssertEqual(string.lowercased(), "seen")
            return "nees"
        }

        var parser = ResponseParser(bufferLimit: 1000, bodySizeLimit: 10, parsedStringCache: testCache)
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen))\r\n"
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.simpleAttribute(.flags([.init("\\nees")]))))
        )
    }

    // Even with a `literalSizeLimit` of 1 parsing a RFC822.TEXT should _not_ fail
    // if the `bodySizeLimit` is large enough.
    func testSeparateLiteralSizeLimit() {
        var parser = ResponseParser(bufferLimit: 1000, bodySizeLimit: 10, literalSizeLimit: 1)
        var buffer: ByteBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(
            try parser.parseResponseStream(buffer: &buffer),
            .response(.fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3)))
        )
    }
}

// MARK: - Stress tests

extension ResponseParser_Tests {
    func testStateIsEnforce() {
        var parser = ResponseParser()
        var input = ByteBuffer(string: "* 1 FETCH (* 2 FETCH \n")

        XCTAssertEqual(try parser.parseResponseStream(buffer: &input), .response(.fetch(.start(1))))
        XCTAssertThrowsError(try parser.parseResponseStream(buffer: &input))
    }
}
