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
            XCTAssertEqual(try path.makeSubMailbox(displayName: newName), newPath, line: line)
        }

        // sad path test make sure that mailbox size limit is enforced
        XCTAssertThrowsError(
            try MailboxPath(name: .init(ByteBuffer(string: String(repeating: "a", count: 999))), pathSeparator: "/").makeSubMailbox(displayName: "1")
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
            XCTAssertEqual(try MailboxPath.makeRootMailbox(displayName: newName, pathSeparator: separator), newPath, line: line)
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

    func testCustomDebugStringConvertible() {
        let inputs: [(MailboxName, String, UInt)] = [
            (.inbox, "INBOX", #line),
            (.init(ByteBuffer()), "", #line),
            (.init(ByteBuffer("Food")), "Food", #line),
            (.init(ByteBuffer("food")), "food", #line),
            (.init(ByteBuffer("FOOD")), "FOOD", #line),
            (.init(ByteBuffer("box/&AKM-")), "box/&AKM-", #line),
            (.init(ByteBuffer("a\u{11}b")), "a\u{11}b", #line),
            (.init(ByteBuffer("båd")), "båd", #line),
        ]
        for (name, expected, line) in inputs {
            XCTAssertEqual(name.debugDescription, expected, line: line)
        }
    }
}

// MARK: - MailboxName

extension MailboxName_Tests {
    func testMailboxNameInitInbox() {
        let test1 = MailboxName("INBOX")
        XCTAssertEqual(test1.bytes, Array("INBOX".utf8))
        XCTAssertTrue(test1.isInbox)

        let test2 = MailboxName("inbox")
        XCTAssertEqual(test2.bytes, Array("INBOX".utf8))
        XCTAssertTrue(test2.isInbox)

        let test3 = MailboxName("Inbox")
        XCTAssertEqual(test3.bytes, Array("INBOX".utf8))
        XCTAssertTrue(test3.isInbox)

        let test4 = MailboxName("notinbox")
        XCTAssertEqual(test4.bytes, Array("notinbox".utf8))
        XCTAssertFalse(test4.isInbox)

        let test5 = MailboxName("inBox2")
        XCTAssertEqual(test5.bytes, Array("inBox2".utf8))
        XCTAssertFalse(test5.isInbox)
    }

    func testMailboxNameInitNonUTF8() {
        let hexBytes: [UInt8] = [0x80]
        let test1 = MailboxName(.init(bytes: hexBytes))
        XCTAssertEqual(test1.bytes, hexBytes)
        XCTAssertFalse(test1.isInbox)
    }

    func testEquality() {
        // Since we’re using a custom implementation of Hashable.

        XCTAssertEqual(MailboxName("INBOX"), MailboxName("inbox"))
        XCTAssertEqual(MailboxName("AA"), MailboxName("AA"))
        XCTAssertNotEqual(MailboxName("A"), MailboxName("B"))
        XCTAssertNotEqual(MailboxName("Sent"), MailboxName("Drafts"))
    }

    func testHashValue() {
        // Since we’re using a custom implementation of Hashable.

        func countBits(_ v: Int) -> Int {
            var value = UInt(bitPattern: v)
            var count = 0
            while (value != 0) {
                count += 1
                value = value & (value &- 1)
            }
            return count
        }

        func countChangedBits(_ a: String, _ b: String) -> Int {
            let ma = MailboxName(Array(a.utf8))
            let mb = MailboxName(Array(b.utf8))
            return countBits(ma.hashValue ^ mb.hashValue)
        }

        XCTAssertGreaterThanOrEqual(countChangedBits("A", "B"), 18)
        XCTAssertGreaterThanOrEqual(countChangedBits("A", "AA"), 18)
        XCTAssertGreaterThanOrEqual(countChangedBits("INBOX", "Drafts"), 18)
        XCTAssertGreaterThanOrEqual(countChangedBits("Sent", "Drafts"), 18)
        XCTAssertGreaterThanOrEqual(countChangedBits("Sent", "sent"), 18)
    }
}
