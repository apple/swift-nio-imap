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

class SectionSpecTests: EncodeTestClass {

}

// MARK: - SectionSpecTests imapEncoded
extension SectionSpecTests {
    
    func testImapEncoded_optional_none() {
        let expected = ""
        let size = self.testBuffer.writeSectionSpec(nil)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testImapEncoded_text() {
        let expected = "HEADER"
        let size = self.testBuffer.writeSectionSpec(.text(.header))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testImapEncoded_part_notext() {
        let expected = "1.2.3.4"
        let size = self.testBuffer.writeSectionSpec(.part([1, 2, 3, 4], text: nil))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testImapEncoded_part_sometext() {
        let expected = "1.2.3.4.HEADER"
        let size = self.testBuffer.writeSectionSpec(.part([1, 2, 3, 4], text: .message(.header)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
