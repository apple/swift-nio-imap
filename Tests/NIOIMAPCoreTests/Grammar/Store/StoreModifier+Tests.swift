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

class StoreModifier_Tests: EncodeTestClass {}

// MARK: - Encoding

extension StoreModifier_Tests {
    func testEncode() {
        let inputs: [(NIOIMAP.StoreModifier, String, UInt)] = [
            (.init(name: "name", parameters: nil), "name", #line),
            (.init(name: "name", parameters: .simple(.number(1))), "name 1", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeStoreModifier(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }

    func testEncode_array() {
        let inputs: [([NIOIMAP.StoreModifier], String, UInt)] = [
            ([.init(name: "name", parameters: nil)], " (name)", #line),
            ([.init(name: "name1", parameters: nil), .init(name: "name2", parameters: nil)], " (name1 name2)", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeStoreModifiers(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
