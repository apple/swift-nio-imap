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

class QuotaResponseTests: EncodeTestClass {}

// MARK: - Encoding

extension QuotaResponseTests {
    func testEncode() {
        let expectedString = "QUOTA \"Root\" ()"
        self.testBuffer.clear()
        let size = self.testBuffer.writeQuotaResponse(quotaRoot: .init("Root"), resources: [])
        XCTAssertEqual(size, expectedString.utf8.count)
        XCTAssertEqual(self.testBufferString, expectedString)
    }

    func testEncodeQuoteResources() {
        let inputs: [([QuotaResource], String, UInt)] = [
            ([QuotaResource(resourceName: "STORAGE", usage: 10, limit: 512)], "(STORAGE 10 512)", #line),
            ([], "()", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeQuotaResources(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
