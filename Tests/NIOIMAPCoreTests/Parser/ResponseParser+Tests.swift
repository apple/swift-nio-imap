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
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingBytes("0123456789"))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingEnd)))
    }

    func testParseResponseStream() {
        let inputs: [(String, [ResponseOrContinuationRequest], UInt)] = [
            ("+ OK Continue", [.continuationRequest(.responseText(.init(text: "OK Continue")))], #line),
            ("1 OK NOOP Completed", [.response(.tagged(.init(tag: "1", state: .ok(.init(text: "NOOP Completed")))))], #line),
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
                        .fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 47)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1772), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 40)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 2778), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true)))
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
                        .fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 50)), fields: .init(parameters: ["CHARSET": "UTF-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 3034), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "_____5C088583DDA30A778CEA0F5BFE2856D1"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true)))
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
                        .fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 5)), fields: .init(parameters: ["CHARSET": "UTF-8"], id: nil, contentDescription: nil, encoding: .sevenBit, octetCount: 221), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 20)), fields: .init(parameters: ["CHARSET": "UTF-8"], id: nil, contentDescription: nil, encoding: .sevenBit, octetCount: 2075), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c", "CHARSET": "UTF-8"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true)))
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
                        .fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 4078)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 239844), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 4078)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 239844), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "===============8996999810533184102=="], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true)))
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
                        .fetch(.simpleAttribute(.body(.valid(.singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 603)), fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .binary, octetCount: 28803), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true)))
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
                        .fetch(.simpleAttribute(.body(.valid(.singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 30)), fields: .init(parameters: ["CHARSET": "utf-8"], id: "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>", contentDescription: nil, encoding: .base64, octetCount: 2340), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: ["EN-US"], location: .init(location: nil, extensions: []))))))), hasExtensionData: true)))
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
                            .simpleAttribute(.body(.valid(.multipart(.init(parts: [
                                .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 170)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 6990), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                .multipart(.init(parts: [
                                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 274)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 18865), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(kind: .basic(.init(topLevel: .application, sub: .init("OCTET-STREAM"))), fields: .init(parameters: ["X-UNIX-MODE": "0644", "NAME": "Whiteboard on Webex.key"], id: nil, contentDescription: nil, encoding: .base64, octetCount: 4876604), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "ATTACHMENT", parameters: ["FILENAME": "Whiteboard on Webex.key"]), language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 17)), fields: .init(parameters: ["CHARSET": "us-ascii"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1143), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(kind: .basic(.init(topLevel: .application, sub: .init("PDF"))), fields: .init(parameters: ["X-UNIX-MODE": "0644", "NAME": "Whiteboard on Webex.pdf"], id: nil, contentDescription: nil, encoding: .base64, octetCount: 1191444), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: ["FILENAME": "Whiteboard on Webex.pdf"]), language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 32)), fields: .init(parameters: ["CHARSET": "us-ascii"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 2217), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(kind: .basic(.init(topLevel: .application, sub: .init("PDF"))), fields: .init(parameters: ["X-UNIX-MODE": "0666", "NAME": "Resume.pdf"], id: nil, contentDescription: nil, encoding: .base64, octetCount: 217550), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: ["FILENAME": "Resume.pdf"]), language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 62)), fields: .init(parameters: ["CHARSET": "utf-8"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 4450), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                                ], mediaSubtype: .mixed, extension: .init(parameters: ["BOUNDARY": "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: [])))))),
                            ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: .init(location: nil, extensions: []))))))), hasExtensionData: true))
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
                    .response(.fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                        .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 0)), fields: BodyStructure.Fields(parameters: [:], id: nil, contentDescription: nil, encoding: .sevenBit, octetCount: 151), extension: BodyStructure.Singlepart.Extension(digest: nil, dispositionAndLanguage: BodyStructure.DispositionAndLanguage(disposition: nil, language: BodyStructure.LanguageLocation(languages: [], location: nil))))),
                    ], mediaSubtype: .mixed, extension: .init(parameters: ["BOUNDARY": "----=rfsewr"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [], location: nil)))))), hasExtensionData: true)))),
                    .response(.fetch(.finish)),
                ],
                #line
            ),
            (
                #"* 433 FETCH (BODYSTRUCTURE (((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 710 20 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4323 42 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "4__=rtfgha") NIL NIL)("IMAGE" "JPEG" ("NAME" "bike.jpeg") "<2__=lgkfjr>" NIL "BASE64" 64 NIL ("INLINE" ("FILENAME" "bike.jpeg")) NIL) "RELATED" ("BOUNDARY" "0__=rtfgaa") NIL NIL)("APPLICATION" "PDF" ("NAME" "title.pdf") "<5__=jlgkfr>" NIL "BASE64" 333980 NIL ("ATTACHMENT" ("FILENAME" "list.pdf")) NIL) "MIXED" ("BOUNDARY" "1__=tfgrhs") NIL NIL))"#,
                [
                    .response(.fetch(.start(433))),
                    .response(
                        .fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                            .multipart(
                                .init(parts: [
                                    .multipart(
                                        .init(parts: [
                                            .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 20)), fields: .init(parameters: ["CHARSET": "ISO-8859-1"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 710), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))),
                                            .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 42)), fields: .init(parameters: ["CHARSET": "ISO-8859-1"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 4323), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: [:]), language: .init(languages: []))))),
                                        ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "4__=rtfgha"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))
                                    ),
                                    .singlepart(.init(kind: .basic(.init(topLevel: .image, sub: .init("JPEG"))), fields: .init(parameters: ["NAME": "bike.jpeg"], id: "<2__=lgkfjr>", contentDescription: nil, encoding: .base64, octetCount: 64), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: ["FILENAME": "bike.jpeg"]), language: .init(languages: []))))),
                                ], mediaSubtype: .related, extension: .init(parameters: ["BOUNDARY": "0__=rtfgaa"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))
                            ),
                            .singlepart(.init(kind: .basic(.init(topLevel: .application, sub: .init("PDF"))), fields: .init(parameters: ["NAME": "title.pdf"], id: "<5__=jlgkfr>", contentDescription: nil, encoding: .base64, octetCount: 333980), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "ATTACHMENT", parameters: ["FILENAME": "list.pdf"]), language: .init(languages: []))))),
                        ], mediaSubtype: .mixed, extension: .init(parameters: ["BOUNDARY": "1__=tfgrhs"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [])))))), hasExtensionData: true))
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
                        .fetch(.simpleAttribute(.body(.valid(.multipart(.init(parts: [
                            .multipart(
                                .init(parts: [
                                    .singlepart(.init(kind: .text(.init(mediaSubtype: "PLAIN", lineCount: 24)), fields: .init(parameters: ["CHARSET": "ISO-8859-1"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 410), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))),
                                    .singlepart(.init(kind: .text(.init(mediaSubtype: "HTML", lineCount: 30)), fields: .init(parameters: ["CHARSET": "ISO-8859-1"], id: nil, contentDescription: nil, encoding: .quotedPrintable, octetCount: 1407), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: [:]), language: .init(languages: []))))),
                                ], mediaSubtype: .alternative, extension: .init(parameters: ["BOUNDARY": "hqjksdm1__="], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: []))))
                            ),
                            .singlepart(
                                .init(kind: .basic(.init(topLevel: .image, sub: .init("PNG"))), fields: BodyStructure.Fields(parameters: ["NAME": "screenshot.png"], id: "<3__=f2fcxd>", contentDescription: nil, encoding: .base64, octetCount: 40655), extension: .init(digest: nil, dispositionAndLanguage: .init(disposition: .init(kind: "INLINE", parameters: ["FILENAME": "screenshot.png"]), language: .init(languages: []))))
                            ),
                        ], mediaSubtype: .related, extension: .init(parameters: ["BOUNDARY": "5__=hsdqjkm"], dispositionAndLanguage: .init(disposition: nil, language: .init(languages: [])))))), hasExtensionData: true)))
                    ),
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

    func testAttributeLimit_failOnStreaming() {
        var parser = ResponseParser(bufferLimit: 1000, messageAttributeLimit: 3)
        var buffer: ByteBuffer = "* 999 FETCH (FLAGS (\\Seen) UID 1 RFC822.SIZE 123 RFC822.TEXT {3}\r\n "

        // limit is 3, so let's parse the first 3
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.flags([.seen])))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.uid(1)))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.rfc822Size(123)))))

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
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.flags([.seen])))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.uid(1)))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.rfc822Size(123)))))

        // the limit is 3, so the fourth should fail
        XCTAssertThrowsError(try parser.parseResponseStream(buffer: &buffer)) { e in
            XCTAssertTrue(e is ExceededMaximumMessageAttributesError)
        }
    }

    func testRejectLargeBodies() {
        var parser = ResponseParser(bufferLimit: 1000, bodySizeLimit: 10)
        var buffer: ByteBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3))))
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
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.flags([.seen])))))
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
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.simpleAttribute(.flags([.init("\\nees")])))))
    }

    // Even with a `literalSizeLimit` of 1 parsing a RFC822.TEXT should _not_ fail
    // if the `bodySizeLimit` is large enough.
    func testSeparateLiteralSizeLimit() {
        var parser = ResponseParser(bufferLimit: 1000, bodySizeLimit: 10, literalSizeLimit: 1)
        var buffer: ByteBuffer = "* 999 FETCH (RFC822.TEXT {3}\r\n123 RFC822.HEADER {11}\r\n "
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.start(999))))
        XCTAssertEqual(try parser.parseResponseStream(buffer: &buffer), .response(.fetch(.streamingBegin(kind: .rfc822Text, byteCount: 3))))
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
