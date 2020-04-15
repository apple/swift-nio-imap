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
@testable import IMAPCore
@testable import NIOIMAP

class MediaBasicTests: EncodeTestClass {

}

// MARK: - Encoding
extension MediaBasicTests {

    func testEncode_basicType() {
        let inputs: [(IMAPCore.Media.BasicType, String, UInt)] = [
            (.application, #""APPLICATION""#, #line),
            (.video, #""VIDEO""#, #line),
            (.image, #""IMAGE""#, #line),
            (.audio, #""AUDIO""#, #line),
            (.message, #""MESSAGE""#, #line),
            (.font, #""FONT""#, #line),
            (.other("type"), "\"type\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMediaBasicType(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode() {
        let inputs: [(IMAPCore.Media.Basic, String, UInt)] = [
            (IMAPCore.Media.Basic(type: .message, subtype: "subtype"), "\"MESSAGE\" \"subtype\"", #line)
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeMediaBasic(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
