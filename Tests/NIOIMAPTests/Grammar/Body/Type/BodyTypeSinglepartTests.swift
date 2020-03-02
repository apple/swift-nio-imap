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

import XCTest
import NIO
@testable import NIOIMAP

class BodyTypeSinglepartTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyTypeSinglepartTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.TypeSinglepart, String, UInt)] = [
            (
                .type(.basic(.init(media: .type(.application, subtype: "subtype"), fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6))), extension: nil),
                "\"APPLICATION\" \"subtype\" () NIL NIL \"BASE64\" 6",
                #line
            ),
            (
                .type(.basic(.init(media: .type(.application, subtype: "subtype"), fields: .parameter([], id: "id", description: "desc", encoding: .base64, octets: 7))), extension: .fieldMD5("md5", dspLanguage: nil)),
                "\"APPLICATION\" \"subtype\" () \"id\" \"desc\" \"BASE64\" 7 \"md5\"",
                #line
            ),
            (
                .type(.text(.init(mediaText: "subtype", fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6), lines: 5)), extension: nil),
                "\"TEXT\" \"subtype\" () NIL NIL \"BASE64\" 6 5",
                #line
            ),
            (
                .type(.message(.init(
                    message: .rfc822,
                    fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6),
                    envelope: .init(date: "date", subject: nil, from: nil, sender: nil, reply: nil, to: nil, cc: nil, bcc: nil, inReplyTo: nil, messageID: nil),
                    body: .singlepart(.type(.text(.init(
                        mediaText: "subtype",
                        fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 6),
                        lines: 5
                    )), extension: nil)),
                    fieldLines: 8
                )), extension: nil),
                "\"MESSAGE\" \"RFC822\" () NIL NIL \"BASE64\" 6 (\"date\" NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"TEXT\" \"subtype\" () NIL NIL \"BASE64\" 6 5) 8",
                #line
            )
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeSinglepart(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
