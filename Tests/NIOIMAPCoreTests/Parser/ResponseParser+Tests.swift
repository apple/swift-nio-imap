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
        
        let inputs: [(String, [ResponseOrContinueRequest], UInt)] = [
//            ("+ OK Continue", [.continueRequest(.responseText(.init(text: "OK Continue")))], #line),
//            ("1 OK NOOP Completed", [.response(.taggedResponse(.init(tag: "1", state: .ok(.init(text: "NOOP Completed")))))], #line),
//            (
//                "* 999 FETCH (FLAGS (\\Also Seen))",
//                [
//                    .response(.fetchResponse(.start(999))),
//                    .response(.fetchResponse(.simpleAttribute(.flags([.seen])))),
//                    .response(.fetchResponse(.finish)),
//                ],
//                #line
//            ),
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
            )
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
