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
                .init(
                    type: .basic(.init(media: .init(type: .application, subtype: .alternative))),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6),
                    extension: nil
                ),
                "\"APPLICATION\" \"multipart/alternative\" NIL NIL NIL \"BASE64\" 6",
                #line
            ),
            (
                .init(
                    type: .basic(.init(media: .init(type: .application, subtype: .related))),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 7),
                    extension: .init(fieldMD5: "md5", dspLanguage: nil)
                ),
                "\"APPLICATION\" \"multipart/related\" NIL NIL NIL \"BASE64\" 7 \"md5\"",
                #line
            ),
            (
                .init(
                    type: .text(.init(mediaText: "subtype", lines: 5)),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6),
                    extension: nil
                ),
                "\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5",
                #line
            ),
            (
                .init(
                    type: .message(
                        .init(
                            message: .rfc822,
                            envelope: .init(date: "date", subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                            body: .singlepart(
                                .init(
                                    type: .text(.init(mediaText: "subtype", lines: 5)),
                                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6),
                                    extension: nil
                                )
                            ),
                            fieldLines: 8
                        )
                    ),
                    fields: .init(parameter: [], id: nil, description: nil, encoding: .base64, octets: 6),
                    extension: nil
                ),
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

    func testEncode_extension() {
        let inputs: [(BodyStructure.Singlepart.Extension, String, UInt)] = [
            (.init(fieldMD5: nil, dspLanguage: nil), "NIL", #line),
            (.init(fieldMD5: "md5", dspLanguage: nil), "\"md5\"", #line),
            (.init(fieldMD5: "md5", dspLanguage: .init(fieldDSP: .init(string: "string", parameter: []), fieldLanguage: nil)), "\"md5\" (\"string\" NIL)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtensionSinglePart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
