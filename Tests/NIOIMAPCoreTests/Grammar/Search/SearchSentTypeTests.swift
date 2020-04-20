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

class SearchSentTypeTests: EncodeTestClass {
    
}

// MARK: - IMAP
extension SearchSentTypeTests {

    func testImapEncoded_before() {
        let expected = "SENTBEFORE 25-jun-1994"
        let size = self.testBuffer.writeSearchSentType(NIOIMAP.SearchSentType.before(NIOIMAP.Date(day: 25, month: .jun, year: 1994)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testImapEncoded_on() {
        let expected = "SENTON 7-dec-2018" 
        let size = self.testBuffer.writeSearchSentType(NIOIMAP.SearchSentType.on(NIOIMAP.Date(day: 07, month: .dec, year: 2018)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
    func testImapEncoded_since() {
        let expected = "SENTSINCE 16-sep-1999"
        let size = self.testBuffer.writeSearchSentType(NIOIMAP.SearchSentType.since(NIOIMAP.Date(day: 16, month: .sep, year: 1999)))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
    
}
