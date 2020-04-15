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

class FetchTests: EncodeTestClass {
    
}

// MARK: - FetchType
extension FetchTests {
    
    func testFetchTypeImapEncoding() {
        let expected = "ALL"
        let size = self.testBuffer.writeFetchType(IMAPCore.FetchType.all)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}

// MARK: - RFC822
extension FetchTests {
    
    func testRFC822ImapEncoding() {
        let expected = ".HEADER"
        let size = self.testBuffer.writeRFC822(IMAPCore.RFC822.header)
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
