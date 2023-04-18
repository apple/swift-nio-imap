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

class SearchReturnOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension SearchReturnOption_Tests {
    func testEncode() {
        let inputs: [(SearchReturnOption, String, UInt)] = [
            (.min, "MIN", #line),
            (.max, "MAX", #line),
            (.all, "ALL", #line),
            (.count, "COUNT", #line),
            (.save, "SAVE", #line),
            (.optionExtension(.init(key: "modifier", value: nil)), "modifier", #line),
            (.partial(.first(23_500 ... 24_000)), "PARTIAL 23500:24000", #line),
            (.partial(.last(1 ... 100)), "PARTIAL -1:-100", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchReturnOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_multiple() {
        let inputs: [([SearchReturnOption], String, UInt)] = [
            ([], "", #line),
            ([.min], " RETURN (MIN)", #line),
            ([.all], " RETURN ()", #line),
            ([.min, .all], " RETURN (MIN ALL)", #line),
            ([.min, .max, .count], " RETURN (MIN MAX COUNT)", #line),
            ([.min, .partial(.last(400 ... 1_000))], " RETURN (MIN PARTIAL -400:-1000)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchReturnOptions(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
