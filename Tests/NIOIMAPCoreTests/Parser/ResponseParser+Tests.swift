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
    
    func testParseResponseStream() {
        
        /*
         * 12187 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 6990 170 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 18865 274 NIL NIL NIL NIL)("APPLICATION" "OCTET-STREAM" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.key") NIL NIL "BASE64" 4876604 NIL ("ATTACHMENT" ("FILENAME" "Whiteboard on Webex.key")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 1143 17 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0644" "NAME" "Whiteboard on Webex.pdf") NIL NIL "BASE64" 1191444 NIL ("INLINE" ("FILENAME" "Whiteboard on Webex.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "us-ascii") NIL NIL "QUOTED-PRINTABLE" 2217 32 NIL NIL NIL NIL)("APPLICATION" "PDF" ("X-UNIX-MODE" "0666" "NAME" "Resume.pdf") NIL NIL "BASE64" 217550 NIL ("INLINE" ("FILENAME" "Resume.pdf")) NIL NIL)("TEXT" "HTML" ("CHARSET" "utf-8") NIL NIL "QUOTED-PRINTABLE" 4450 62 NIL NIL NIL NIL) "MIXED" ("BOUNDARY" "Apple-Mail=_1B76125E-EB81-4B78-A023-B30D1F9070F2") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "Apple-Mail=_2F0988E2-CA7E-4379-B088-7E556A97E21F") NIL NIL NIL))
         */
        
        let inputs: [(String, [ResponseOrContinueRequest], UInt)] = [
            ("+ OK Continue", [.continueRequest(.responseText(.init(text: "OK Continue")))], #line),
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
                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lines: 47)), fields: .init(parameter: [.init(field: "CHARSET", value: "utf-8")], id: nil, description: nil, encoding: .quotedPrintable, octets: 1772), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lines: 40)), fields: .init(parameter: [.init(field: "CHARSET", value: "utf-8")], id: nil, description: nil, encoding: .quotedPrintable, octets: 2778), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), multipartExtension: .init(parameters: [.init(field: "BOUNDARY", value: "Apple-Mail=_0D97185D-4FF1-42FE-9B8F-A0759D299015")], dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))), structure: true)))
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
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lines: 50)), fields: .init(parameter: [.init(field: "CHARSET", value: "UTF-8")], id: nil, description: nil, encoding: .quotedPrintable, octets: 3034), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), multipartExtension: .init(parameters: [.init(field: "BOUNDARY", value: "_____5C088583DDA30A778CEA0F5BFE2856D1")], dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))), structure: true)))
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
                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lines: 5)), fields: .init(parameter: [.init(field: "CHARSET", value: "UTF-8")], id: nil, description: nil, encoding: .sevenBit, octets: 221), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lines: 20)), fields: .init(parameter: [.init(field: "CHARSET", value: "UTF-8")], id: nil, description: nil, encoding: .sevenBit, octets: 2075), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), multipartExtension: .init(parameters: [.init(field: "BOUNDARY", value: "--==_mimepart_5efddab8ca39a_6a343f841aacb93410876c"), .init(field: "CHARSET", value: "UTF-8")], dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))), structure: true)))
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
                            .singlepart(.init(type: .text(.init(mediaText: "PLAIN", lines: 4078)), fields: .init(parameter: [.init(field: "CHARSET", value: "utf-8")], id: nil, description: nil, encoding: .quotedPrintable, octets: 239844), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                            .singlepart(.init(type: .text(.init(mediaText: "HTML", lines: 4078)), fields: .init(parameter: [.init(field: "CHARSET", value: "utf-8")], id: nil, description: nil, encoding: .quotedPrintable, octets: 239844), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))),
                        ], mediaSubtype: .init("ALTERNATIVE"), multipartExtension: .init(parameters: [.init(field: "BOUNDARY", value: "===============8996999810533184102==")], dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))), structure: true)))
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
                        .fetchResponse(.simpleAttribute(.body(.singlepart(.init(type: .text(.init(mediaText: "HTML", lines: 603)), fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octets: 28803), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(nil), location: .init(location: nil, extensions: [])))))), structure: true)))
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
                        .fetchResponse(.simpleAttribute(.body(.singlepart(.init(type: .text(.init(mediaText: "PLAIN", lines: 30)), fields: .init(parameter: [.init(field: "CHARSET", value: "utf-8")], id: "<DDB621064D883242BBC8DBE205F0250F@pex.exch.apple.com>", description: nil, encoding: .base64, octets: 2340), extension: .init(fieldMD5: nil, dspLanguage: .init(fieldDisposition: nil, fieldLanguage: .init(language: .single(.init("EN-US")), location: .init(location: nil, extensions: [])))))), structure: true)))
                    ),
                    .response(.fetchResponse(.finish)),
                ],
                #line
            ),
        ]
        
        for (input, expected, line) in inputs {
            var buffer = ByteBuffer(string: input + "\r\n")
            var results = [ResponseOrContinueRequest]()
            var parser = ResponseParser(expectGreeting: false)
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
