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
        let inputs: [(MailboxName, Character, Bool, [String], UInt)] = [
            (.init("ABC"), .init("B"), true, ["A", "C"], #line),
            (.init("ABC"), .init("D"), true, ["ABC"], #line),
            (.init(""), .init("D"), true, [], #line),
            (.init("some/real/mailbox"), .init("/"), true, ["some", "real", "mailbox"], #line),
            (.init("mailbox#test"), .init("#"), true, ["mailbox", "test"], #line),
            (.init("//test1//test2//"), .init("/"), true, ["test1", "test2"], #line),
            (.init("//test1//test2//"), .init("/"), false, ["", "", "test1", "", "test2", "", ""], #line),
        ]
        for (name, character, ommitEmpty, expected, line) in inputs {
            XCTAssertEqual(name.displayStringComponents(separator: character, omittingEmptySubsequences: ommitEmpty), expected, line: line)
        }
    }
}
