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

class BodyTypeMessageTests: EncodeTestClass {

}

// MARK: - Encoding
extension BodyTypeMessageTests {

    func testEncode() {
        let inputs: [(NIOIMAP.Body.TypeMessage, String, UInt)] = [
            (
                .message(
                    .rfc822,
                    fields: .parameter([], id: nil, description: nil, encoding: .base64, octets: 111),
                    envelope: NIOIMAP.Envelope(date: "date", subject: nil, from: nil, sender: nil, reply: nil, to: nil, cc: nil, bcc: nil, inReplyTo: nil, messageID: nil),
                    body: .singlepart(.type(.text(.mediaText("subtype",
                            fields: .parameter([], id: nil, description: nil, encoding: .binary, octets: 22),
                            lines: 33
                        )),
                        extension: nil
                    )),
                    fieldLines: 89
                ),
                "\"MESSAGE\" \"RFC822\" () NIL NIL \"BASE64\" 111 (\"date\" NIL NIL NIL NIL NIL NIL NIL NIL NIL) (\"TEXT\" \"subtype\" () NIL NIL \"BINARY\" 22 33) 89",
                #line
            )
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeBodyTypeMessage(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
