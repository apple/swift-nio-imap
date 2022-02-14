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
import XCTest

class BodySinglepartTests: EncodeTestClass {}

// MARK: - Encoding

extension BodySinglepartTests {
    func testEncode() {
        let inputs: [(BodyStructure.Singlepart, String, UInt)] = [
            (
                .init(
                    kind: .basic(.init(kind: .application, subtype: .init("jpeg"))),
                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                    extension: nil
                ),
                "\"application\" \"jpeg\" NIL NIL NIL \"BASE64\" 6",
                #line
            ),
            (
                .init(
                    kind: .basic(.init(kind: .application, subtype: .init("jpeg"))),
                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 7),
                    extension: .init(digest: "md5", dispositionAndLanguage: nil)
                ),
                "\"application\" \"jpeg\" NIL NIL NIL \"BASE64\" 7 \"md5\"",
                #line
            ),
            (
                .init(
                    kind: .text(.init(mediaText: "html", lineCount: 5)),
                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                    extension: nil
                ),
                "\"TEXT\" \"html\" NIL NIL NIL \"BASE64\" 6 5",
                #line
            ),
            (
                .init(
                    kind: .message(
                        .init(
                            message: .rfc822,
                            envelope: .init(date: "date", subject: nil, from: [], sender: [], reply: [], to: [], cc: [], bcc: [], inReplyTo: nil, messageID: nil),
                            body: .singlepart(
                                .init(
                                    kind: .text(.init(mediaText: "subtype", lineCount: 5)),
                                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                                    extension: nil
                                )
                            ),
                            lineCount: 8
                        )
                    ),
                    fields: .init(parameters: [:], id: nil, contentDescription: nil, encoding: .base64, octetCount: 6),
                    extension: nil
                ),
                "\"MESSAGE\" \"RFC822\" NIL NIL NIL \"BASE64\" 6 (\"date\" NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"TEXT\" \"subtype\" NIL NIL NIL \"BASE64\" 6 5) 8",
                #line
            ),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodySinglepart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_extension() {
        let inputs: [(BodyStructure.Singlepart.Extension, String, UInt)] = [
            (.init(digest: nil, dispositionAndLanguage: nil), "NIL", #line),
            (.init(digest: "md5", dispositionAndLanguage: nil), "\"md5\"", #line),
            (.init(digest: "md5", dispositionAndLanguage: .init(disposition: .init(kind: "string", parameters: [:]), language: nil)), "\"md5\" (\"string\" NIL)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyExtensionSinglePart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
