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

class SearchSentTypeTests: EncodeTestClass {}

// MARK: - IMAP

extension SearchSentTypeTests {
    func testImapEncoded_before() {
        let expected = "SENTBEFORE 25-Jun-1994"
        let size = self.testBuffer.writeSearchSentType(SearchSentType.before(Date(year: 1994, month: 6, day: 25)!))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testImapEncoded_on() {
        let expected = "SENTON 7-Dec-2018"
        let size = self.testBuffer.writeSearchSentType(SearchSentType.on(Date(year: 2018, month: 12, day: 07)!))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }

    func testImapEncoded_since() {
        let expected = "SENTSINCE 16-Sep-1999"
        let size = self.testBuffer.writeSearchSentType(SearchSentType.since(Date(year: 1999, month: 9, day: 16)!))
        XCTAssertEqual(size, expected.utf8.count)
        XCTAssertEqual(expected, self.testBufferString)
    }
}
