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

class MailboxName_Tests: EncodeTestClass {}

// MARK: - displayStringComponents

extension MailboxName_Tests {
    
    func testSplitting() {
        let inputs: [(MailboxName, Character, [String], UInt)] = [
            (.init("ABC"), .init("B"), ["A", "C"], #line),
            (.init("ABC"), .init("D"), ["ABC"], #line),
            (.init(""), .init("D"), [], #line),
        ]
        for (name, character, expected, line) in inputs {
            XCTAssertEqual(name.displayStringComponents(separator: character), expected, line: line)
        }
    }
    
}
