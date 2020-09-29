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

// MARK: - MailboxPath

extension MailboxName_Tests {
    func testInit() {
        let test1 = MailboxPath(name: .init("box"), pathSeparator: nil)
        XCTAssertEqual(test1.name, .init("box"))
        XCTAssertEqual(test1.pathSeparator, nil)

        let test2 = MailboxPath(name: .init("box"))
        XCTAssertEqual(test2.name, .init("box"))
        XCTAssertEqual(test2.pathSeparator, nil)

        let test3 = MailboxPath(name: .init("box"), pathSeparator: "/")
        XCTAssertEqual(test3.name, .init("box"))
        XCTAssertEqual(test3.pathSeparator, "/")
    }

    func testCreateSubMailboxWithDisplayName() {
        let inputs: [(MailboxPath, String, MailboxPath, UInt)] = [
            (
                .init(name: .init("box1"), pathSeparator: nil),
                "box2",
                .init(name: .init("box1box2"), pathSeparator: nil),
                #line
            ),
            (
                .init(name: .init("box"), pathSeparator: "/"),
                "£",
                .init(name: .init("box/&AKM-"), pathSeparator: "/"),
                #line
            ),
        ]
        for (path, newName, newPath, line) in inputs {
            XCTAssertEqual(path.makeSubMailbox(displayName: newName), newPath, line: line)
        }
    }
    
    func testSplitting() {
        let inputs: [(MailboxPath, Bool, [String], UInt)] = [
            (.init(name: .init("ABC"), pathSeparator: "B"), true, ["A", "C"], #line),
            (.init(name: .init("ABC"), pathSeparator: "D"), true, ["ABC"], #line),
            (.init(name: .init(""), pathSeparator: "D"), true, [], #line),
            (.init(name: .init("some/real/mailbox"), pathSeparator: "/"), true, ["some", "real", "mailbox"], #line),
            (.init(name: .init("mailbox#test"), pathSeparator: "#"), true, ["mailbox", "test"], #line),
            (.init(name: .init("//test1//test2//"), pathSeparator: "/"), true, ["test1", "test2"], #line),
            (.init(name: .init("//test1//test2//"), pathSeparator: "/"), false, ["", "", "test1", "", "test2", "", ""], #line),
        ]
        for (path, ommitEmpty, expected, line) in inputs {
            XCTAssertEqual(path.displayStringComponents(omittingEmptySubsequences: ommitEmpty), expected, line: line)
        }
    }
}
