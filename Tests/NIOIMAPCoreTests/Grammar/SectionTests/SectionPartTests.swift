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
@testable import NIOIMAPCore

class SectionPartTests: EncodeTestClass {

}

// MARK: - SectionPartTests imapEncoded
extension SectionPartTests {
    
    func testImapEncoded_empty() {
        let expected = ""
        let size = self.testBuffer.writeSectionPart([])
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testImapEncoded_full() {
        let expected = "1.2.3.5.8.11"
        let size = self.testBuffer.writeSectionPart([1, 2, 3, 5, 8, 11])
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
