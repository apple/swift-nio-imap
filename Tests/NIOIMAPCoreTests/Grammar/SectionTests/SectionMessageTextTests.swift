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

class SectionMessageTextTests: EncodeTestClass {}

// MARK: - SectionMessage init

extension SectionMessageTextTests {
    func testInit_header() {
        let expected = "HEADER"
        let size = self.testBuffer.writeSectionMessageText(NIOIMAP.SectionMessageText.header)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testInit_text() {
        let expected = "TEXT"
        let size = self.testBuffer.writeSectionMessageText(NIOIMAP.SectionMessageText.text)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testInit_headerFields() {
        let expected = "HEADER.FIELDS (\"hello world\")"
        let size = self.testBuffer.writeSectionMessageText(NIOIMAP.SectionMessageText.headerFields(["hello world"]))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testInit_noteHeaderFields() {
        let expected = "HEADER.FIELDS.NOT (\"some text\")"
        let size = self.testBuffer.writeSectionMessageText(NIOIMAP.SectionMessageText.notHeaderFields(["some text"]))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
