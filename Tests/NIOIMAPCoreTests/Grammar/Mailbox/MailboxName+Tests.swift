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
        let test1 = try! MailboxPath(name: .init("box"), pathSeparator: nil)
        XCTAssertEqual(test1.name, .init("box"))
        XCTAssertEqual(test1.pathSeparator, nil)

        let test2 = try! MailboxPath(name: .init("box"))
        XCTAssertEqual(test2.name, .init("box"))
        XCTAssertEqual(test2.pathSeparator, nil)

        let test3 = try! MailboxPath(name: .init("box"), pathSeparator: "/")
        XCTAssertEqual(test3.name, .init("box"))
        XCTAssertEqual(test3.pathSeparator, "/")
    }

    func testMakeSubMailboxWithDisplayName() {
        let inputs: [(MailboxPath, String, MailboxPath, UInt)] = [
            (
                try! .init(name: .init("box"), pathSeparator: "/"),
                "£",
                try! .init(name: .init("box/&AKM-"), pathSeparator: "/"),
                #line
            ),
        ]
        for (path, newName, newPath, line) in inputs {
            XCTAssertNoThrow(XCTAssertEqual(try path.makeSubMailbox(displayName: newName), newPath, line: line), line: line)
        }

        // sad path test make sure that mailbox size limit is enforced
        XCTAssertThrowsError(
            try MailboxPath(name: .init(String(repeating: "a", count: 999)), pathSeparator: "/").makeSubMailbox(displayName: "1")
        ) { error in
            XCTAssertEqual(error as! MailboxTooBigError, MailboxTooBigError(maximumSize: 1000, actualSize: 1001))
        }
    }

    func testMakeRootMailboxWithDisplayName() {
        let inputs: [(String, Character?, MailboxPath, UInt)] = [
            (
                "box2",
                nil,
                try! .init(name: .init("box2"), pathSeparator: nil),
                #line
            ),
            (
                "£",
                "/",
                try! .init(name: .init("&AKM-"), pathSeparator: "/"),
                #line
            ),
        ]
        for (newName, separator, newPath, line) in inputs {
            XCTAssertNoThrow(XCTAssertEqual(try MailboxPath.makeRootMailbox(displayName: newName, pathSeparator: separator), newPath, line: line), line: line)
        }

        // sad path test make sure that mailbox size limit is enforced
        XCTAssertThrowsError(
            try MailboxPath.makeRootMailbox(displayName: String(repeating: "a", count: 1001))
        ) { error in
            XCTAssertEqual(error as! MailboxTooBigError, MailboxTooBigError(maximumSize: 1000, actualSize: 1001))
        }
    }

    func testSplitting() {
        let inputs: [(MailboxPath, Bool, [String], UInt)] = [
            (try! .init(name: .init("ABC"), pathSeparator: "B"), true, ["A", "C"], #line),
            (try! .init(name: .init("ABC"), pathSeparator: "D"), true, ["ABC"], #line),
            (try! .init(name: .init(""), pathSeparator: "D"), true, [], #line),
            (try! .init(name: .init("some/real/mailbox"), pathSeparator: "/"), true, ["some", "real", "mailbox"], #line),
            (try! .init(name: .init("mailbox#test"), pathSeparator: "#"), true, ["mailbox", "test"], #line),
            (try! .init(name: .init("//test1//test2//"), pathSeparator: "/"), true, ["test1", "test2"], #line),
            (try! .init(name: .init("//test1//test2//"), pathSeparator: "/"), false, ["", "", "test1", "", "test2", "", ""], #line),
        ]
        for (path, ommitEmpty, expected, line) in inputs {
            XCTAssertEqual(path.displayStringComponents(omittingEmptySubsequences: ommitEmpty), expected, line: line)
        }
    }

    func testCreateSubmailboxWithoutPathSeparatorThrows() {
        let mailbox = try! MailboxPath(name: .inbox, pathSeparator: nil)
        XCTAssertThrowsError(try mailbox.makeSubMailbox(displayName: "sub")) { e in
            XCTAssertTrue(e is InvalidPathSeparatorError)
        }
    }
}
