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

class CommandType_Tests: EncodeTestClass {}

// MARK: - Encoding

extension CommandType_Tests {
    func testEncode() {
        let inputs: [(Command, String, UInt)] = [
            (.list(nil, reference: .init(""), .mailbox(""), []), "LIST \"\" \"\" RETURN ()", #line),
            (.namespace, "NAMESPACE", #line),

            // MARK: Login

            (.login(username: "username", password: "password"), #"LOGIN "username" "password""#, #line),
            (.login(username: "david evans", password: "great password"), #"LOGIN "david evans" "great password""#, #line),
            (.login(username: "\r\n", password: "\\\""), "LOGIN {2}\r\n\r\n {2}\r\n\\\"", #line),
        ]

        for (input, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeCommandType(input)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
