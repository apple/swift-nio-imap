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

class UntaggedStatus_Tests: EncodeTestClass {}

// MARK: - Encoding

extension UntaggedStatus_Tests {
    func testEncode() {
        let inputs: [(UntaggedStatus, String, UInt)] = [
            (.ok(.init(code: .alert, text: "error")), "OK [ALERT] error", #line),
            (.no(.init(code: .readOnly, text: "everything")), "NO [READ-ONLY] everything", #line),
            (.bad(.init(code: .parse, text: "something")), "BAD [PARSE] something", #line),
            (.preauth(.init(code: .capability([.uidPlus]), text: "logged in as Smith")), "PREAUTH [CAPABILITY UIDPLUS] logged in as Smith", #line),
            (.bye(.init(code: .alert, text: "Autologout; idle for too long")), "BYE [ALERT] Autologout; idle for too long", #line),

            (.ok(.init(text: "error")), "OK error", #line),
            (.no(.init(text: "everything")), "NO everything", #line),
            (.bad(.init(text: "something")), "BAD something", #line),
            (.preauth(.init(text: "logged in as Smith")), "PREAUTH logged in as Smith", #line),
            (.bye(.init(text: "Autologout; idle for too long")), "BYE Autologout; idle for too long", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer._clear()
            let size = self.testBuffer.writeUntaggedStatus(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
