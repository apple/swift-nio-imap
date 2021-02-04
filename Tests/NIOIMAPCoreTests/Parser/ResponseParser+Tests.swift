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
        XCTAssertEqual(parser.bufferLimit, 1_000)
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
        XCTAssertNoThrow(XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetchResponse(.streamingBytes("0123456789")))))
        XCTAssertNoThrow(XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetchResponse(.streamingEnd))))
    }

    func testParseResponseStream() {
        let inputs: [(String, [ResponseOrContinuationRequest], UInt)] = [
            ("+ OK Continue", [.continuationRequest(.responseText(.init(text: "OK Continue")))], #line),
            ("1 OK NOOP Completed", [.response(.taggedResponse(.init(tag: "1", state: .ok(.init(text: "NOOP Completed")))))], #line),
            (
                "* 999 FETCH (FLAGS (\\Seen))",
                [
                    .response(.fetchResponse(.start(999))),
                    .response(.fetchResponse(.simpleAttribute(.flags([.seen])))),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12190 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 1772 47 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 2778 40 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015") NIL NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(12190))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 47)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1772), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 40)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 2778), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12194 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 3034 50 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "_____5C088583DDA30A778CEA0F5BFE2856D1") NIL NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(12194))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 50)), fields: .init(parameters: [.init(key: "CHARSET", value: "UTF-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 3034), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "_____5C088583DDA30A778CEA0F5BFE2856D1")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12180 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 221 5 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "7BIT" 2075 20 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c" "CHARSET" "UTF-8") NIL NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(12180))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 5)), fields: .init(parameters: [.init(key: "CHARSET", value: "UTF-8")], id: nil, contentDescription: nil, encoding: .sevenBit, octetCount: 221), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 20)), fields: .init(parameters: [.init(key: "CHARSET", value: "UTF-8")], id: nil, contentDescription: nil, encoding: .sevenBit, octetCount: 2075), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c"), .init(key: "CHARSET", value: "UTF-8")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12182 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 239844 4078 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 239844 4078 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "===============8996999810533184102==") NIL NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(12182))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 4078)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 239844), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 4078)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 239844), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "===============8996999810533184102==")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12183 FETCH (BODYSTRUCTURE ("TEXT" "HTML" NIL NIL NIL "BINARY" 28803 603 NIL NIL NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(12183))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 603)), fields: .init(parameters: [], id: nil, contentDescription: nil, encoding: .binary, octetCount: 28803), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12184 FETCH (BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "utf-8") "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>" NIL "BASE64" 2340 30 NIL NIL ("EN-US") NIL))"#,
                [
                    .response(.fetchResponse(.start(12184))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 30)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>", contentDescription: nil, encoding: .base64, octetCount: 2340), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: ["EN-US"], location: .init(location: nil, extensions: [])))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 12187 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 6990 170 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 18865 274 NIL NIL NIL NIL)("APPLICATION" "OCTET-STREAM" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.key") NIL NIL "BASE64" 4876604 NIL ("ATTACHMENT" ("FILENAME" "Whiteboard on Webex.key")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 1143 17 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.pdf") NIL NIL "BASE64" 1191444 NIL ("INLINE" ("FILENAME" "Whiteboard on Webex.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 2217 32 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0666" "NAME" "Resume.pdf") NIL NIL "BASE64" 217550 NIL ("INLINE" ("FILENAME" "Resume.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 4450 62 NIL NIL NIL NIL) "MIXED" ("BOUNDARY" "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F") NIL NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(12187))),
                    .response(
                        .fetchResponse(
                            .simpleAttribute(.body(.multipart(.init(parts: [
                                .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 170)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 6990), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                .multipart(.init(parts: [
                                    .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 274)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 18865), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(type: .basic(.init(kind: .application, subtype: .init("OCTET-STREAM"))), fields: .init(parameters: [.init(key: "X-UNIX-MODE", value: "0644"), .init(key: "NAME", value: "Whiteboard on Webex.key")], id: nil, contentDescription: nil, encoding: .base64, octetCount: 4876604), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "ATTACHMENT", parameters: [.init(key: "FILENAME", value: "Whiteboard on Webex.key")]), language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 17)), fields: .init(parameters: [.init(key: "CHARSET", value: "us-ascii")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1143), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(type: .basic(.init(kind: .application, subtype: .init("PDF"))), fields: .init(parameters: [.init(key: "X-UNIX-MODE", value: "0644"), .init(key: "NAME", value: "Whiteboard on Webex.pdf")], id: nil, contentDescription: nil, encoding: .base64, octetCount: 1191444), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: [.init(key: "FILENAME", value: "Whiteboard on Webex.pdf")]), language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 32)), fields: .init(parameters: [.init(key: "CHARSET", value: "us-ascii")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 2217), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(type: .basic(.init(kind: .application, subtype: .init("PDF"))), fields: .init(parameters: [.init(key: "X-UNIX-MODE", value: "0666"), .init(key: "NAME", value: "Resume.pdf")], id: nil, contentDescription: nil, encoding: .base64, octetCount: 217550), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: [.init(key: "FILENAME", value: "Resume.pdf")]), language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 62)), fields: .init(parameters: [.init(key: "CHARSET", value: "utf-8")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 4450), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                ], mediaSubtype: .init("MIXED"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))), hasExtensionData: true))
                        )
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 53 FETCH (BODYSTRUCTURE (("TEXT" "HTML" NIL NIL NIL "7BIT" 151 0 NIL NIL NIL) "MIXED" ("BOUNDARY" "----=rfsewr") NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(53))),
                    .response(.fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                        .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 0)), fields: BodyStructure.Fields(parameters: [], id: nil, contentDescription: nil, encoding: .sevenBit, octetCount: 151), extension: BodyStructure.Singlepart.Extension(fieldMD5: nil, dispositionAndLanguage: BodyStructure.DispositionAndLanguage(disposition: nil, language: BodyStructure.LanguageLocation(languages: [], location: nil))))),
                    ], mediaSubtype: .init("MIXED"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "----=rfsewr")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: nil))))), hasExtensionData: true)))),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 433 FETCH (BODYSTRUCTURE (((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 710 20 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4323 42 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "4__=rtfgha") NIL NIL)("IMAGE" "JPEG" ("NAME" "bike.jpeg") "<2__=lgkfjr>" NIL "BASE64" 64 NIL ("INLINE" ("FILENAME" "bike.jpeg")) NIL) "RELATED" ("BOUNDARY" "0__=rtfgaa") NIL NIL)("APPLICATION" "PDF" ("NAME" "title.pdf") "<5__=jlgkfr>" NIL "BASE64" 333980 NIL ("ATTACHMENT" ("FILENAME" "list.pdf")) NIL) "MIXED" ("BOUNDARY" "1__=tfgrhs") NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(433))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                            .multipart(
                                .init(parts: [
                                    .multipart(
                                        .init(parts: [
                                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 20)), fields: .init(parameters: [.init(key: "CHARSET", value: "ISO-8859-1")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 710), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))),
                                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 42)), fields: .init(parameters: [.init(key: "CHARSET", value: "ISO-8859-1")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 4323), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: []), language: .init(languages: []))))),
                                        ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "4__=rtfgha")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))
                                    ),
                                    .singlepart(.init(type: .basic(.init(kind: .image, subtype: .init("JPEG"))), fields: .init(parameters: [.init(key: "NAME", value: "bike.jpeg")], id: "<2__=lgkfjr>", contentDescription: nil, encoding: .base64, octetCount: 64), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: [.init(key: "FILENAME", value: "bike.jpeg")]), language: .init(languages: []))))),
                                ], mediaSubtype: .init("RELATED"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "0__=rtfgaa")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))
                            ),
                            .singlepart(.init(type: .basic(.init(kind: .application, subtype: .init("PDF"))), fields: .init(parameters: [.init(key: "NAME", value: "title.pdf")], id: "<5__=jlgkfr>", contentDescription: nil, encoding: .base64, octetCount: 333980), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "ATTACHMENT", parameters: [.init(key: "FILENAME", value: "list.pdf")]), language: .init(languages: []))))),
                        ], mediaSubtype: .init("MIXED"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "1__=tfgrhs")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))), hasExtensionData: true))
                        )
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
            (
                #"* 234 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 410 24 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 1407 30 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "hqjksdm1__=") NIL NIL)("IMAGE" "PNG" ("NAME" "screenshot.png") "<3__=f2fcxd>" NIL "BASE64" 40655 NIL ("INLINE" ("FILENAME" "screenshot.png")) NIL) "RELATED" ("BOUNDARY" "5__=hsdqjkm") NIL NIL))"#,
                [
                    .response(.fetchResponse(.start(234))),
                    .response(
                        .fetchResponse(.simpleAttribute(.body(.multipart(.init(parts: [
                            .multipart(
                                .init(parts: [
                                    .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lineCount: 24)), fields: .init(parameters: [.init(key: "CHARSET", value: "ISO-8859-1")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 410), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))),
                                    .singlepart(.init(type: .text(.init(mediaText: "HTML", lineCount: 30)), fields: .init(parameters: [.init(key: "CHARSET", value: "ISO-8859-1")], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1407), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: []), language: .init(languages: []))))),
                                ], mediaSubtype: .init("ALTERNATIVE"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "hqjksdm1__=")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))
                            ),
                            .singlepart(
                                .init(type: .basic(.init(kind: .image, subtype: .init("PNG"))), fields: BodyStructure.Fields(parameters: [.init(key: "NAME", value: "screenshot.png")], id: "<3__=f2fcxd>", contentDescription: nil, encoding: .base64, octetCount: 40655), extension: .init(fieldMD5: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: [.init(key: "FILENAME", value: "screenshot.png")]), language: .init(languages: []))))
                            ),
                        ], mediaSubtype: .init("RELATED"), extension: .init(parameters: [.init(key: "BOUNDARY", value: "5__=hsdqjkm")], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))), hasExtensionData: true)))
                    ),
                    .response(.fetchResponse(.finish)),
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
}

// MARK: - Stress tests

extension ResponseParser_Tests {
    func testStateIsEnforce() {
        var parser = ResponseParser()
        var input = ByteBuffer(string: "* 1 FETCH (* 2 FETCH ")

        XCTAssertNoThrow(XCTAssertEqual(try parser.parseResponseStream(buffer: &input), .response(.fetchResponse(.start(1)))))
        XCTAssertThrowsError(try parser.parseResponseStream(buffer: &input))
    }
}
