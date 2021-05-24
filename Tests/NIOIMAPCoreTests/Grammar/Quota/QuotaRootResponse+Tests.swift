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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import XCTest

class QuotaRootResponseTests: EncodeTestClass {}

// MARK: - Encoding

extension QuotaRootResponseTests {
    func testEncode() {
        let expectedString = "QUOTAROOT \"INBOX\" \"Root\""
        self.testBuffer.clear()
        let size = self.testBuffer.writeQuotaRootResponse(mailbox: .init("INBOX"), quotaRoot: .init("Root"))
        XCTAssertEqual(size, expectedString.utf8.count)
        XCTAssertEqual(self.testBufferString, expectedString)
    }
}
