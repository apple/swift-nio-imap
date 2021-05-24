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

class ReturnOption_Tests: EncodeTestClass {}

// MARK: - Encoding

extension ReturnOption_Tests {
    func testEncode() {
        let inputs: [(ReturnOption, String, UInt)] = [
            (.subscribed, "SUBSCRIBED", #line),
            (.children, "CHILDREN", #line),
            (.statusOption([.messageCount]), "STATUS (MESSAGES)", #line),
            (.optionExtension(.init(key: .standard("atom"), value: nil)), "atom", #line),
            (.specialUse, "SPECIAL-USE", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeReturnOption(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
