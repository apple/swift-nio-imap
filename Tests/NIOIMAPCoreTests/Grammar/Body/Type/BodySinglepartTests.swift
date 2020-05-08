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

class BodySinglepartTests: EncodeTestClass {}

// MARK: - Encoding

extension BodySinglepartTests {
    func testEncode() {
        let inputs: [(BodyStructure.Singlepart, String, UInt)] = [
            (
                .init(type: .basic(.init(media: .init(type: .application, subtype: "subtype"), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6))), extension: nil),
                "\"APPLICATION\" \"subtype\" NIL NIL NIL \"BASE64\" 6",
                #line
            ),
            (
                .init(type: .basic(.init(media: .init(type: .application, subtype: "subtype"), fields: .init(parameter: [], id: "id", description: "desc", encoding: .base64, octets: 7))), extension: .init(fieldMD5: "md5", dspLanguage: nil)),
                "\"APPLICATION\" \"subtype\" NIL \"id\" \"desc\" \"BASE64\" 7 \"md5\"",
                #line
            ),
            (
                .init(type: .text(.init(mediaText: "subtype", fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil),
                "\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5",
                #line
            ),
            (
                .init(type: .message(.init(message:
                    .rfc822,
                                           fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6),
                                           envelope: .init(date: "date", subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                                           body: .singlepart(.init(type: .text(.init(mediaText:
                        "subtype",
                                                                                     fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6),
                                                                                     lines: 5)), extension: nil)),
                                           fieldLines: 8)), extension: nil),
                "\"MESSAGE\" \"RFC822\" NIL NIL NIL \"BASE64\" 6 (\"date\" NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) 8",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeSinglepart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_basic() {
        let inputs: [(NIOIMAP.BodyStructure.Singlepart.Basic, String, UInt)] = [
            (.init(media: .init(type: .application, subtype: "subtype"), fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 123)), "\"APPLICATION\" \"subtype\" NIL NIL NIL \"BASE64\" 123", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeBasic(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_message() {
        let inputs: [(BodyStructure.Singlepart.Message, String, UInt)] = [
            (
                .init(message:
                    .rfc822,
                      fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 111),
                      envelope: NIOIMAP.Envelope(date: "date", subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                      body: .singlepart(.init(type: .text(.init(mediaText: "subtype",
                                                                fields: .init(parameter: [], id: nil, description: nil, encoding: .binary, octets: 22),
                                                                lines: 33)),
                                              extension: nil)),
                      fieldLines: 89),
                "\"MESSAGE\" \"RFC822\" NIL NIL NIL \"BASE64\" 111 (\"date\" NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"TEXT\" \"subtype\" NIL NIL NIL \"BINARY\" 22 33) 89",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeMessage(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_text() {
        let inputs: [(NIOIMAP.BodyStructure.Singlepart.Text, String, UInt)] = [
            (.init(mediaText: "subtype", fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 123), lines: 456), "\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 123 456", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeText(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_extension() {
        let inputs: [(BodyStructure.Singlepart.Extension, String, UInt)] = [
            (.fieldMD5(nil, dspLanguage: nil), "NIL", #line),
            (.fieldMD5("md5", dspLanguage: nil), "\"md5\"", #line),
            (.fieldMD5("md5", dspLanguage: .fieldDSP(.string("string", parameter: []), fieldLanguage: nil)), "\"md5\" (\"string\" NIL)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtensionSinglePart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
