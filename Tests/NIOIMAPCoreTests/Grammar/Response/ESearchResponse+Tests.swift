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

class ExtendedSearchResponse_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ExtendedSearchResponse_Tests {
    func testEncode() {
        let inputs: [(ExtendedSearchResponse, String, UInt)] = [
            (.init(correlator: nil, uid: false, returnData: []), "ESEARCH", #line),
            (.init(correlator: nil, uid: true, returnData: []), "ESEARCH UID", #line),
            (.init(correlator: nil, uid: false, returnData: [.count(2)]), "ESEARCH COUNT 2", #line),
            (.init(correlator: SearchCorrelator(tag: "some"), uid: false, returnData: []), "ESEARCH (TAG \"some\")", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeExtendedSearchResponse(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
