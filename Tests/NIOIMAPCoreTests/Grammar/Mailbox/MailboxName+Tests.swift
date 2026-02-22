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
import Testing

@Suite("MailboxPath")
private struct MailboxPathTests {
    @Test("initialization with various path separator options")
    func initializationWithVariousPathSeparatorOptions() {
        let test1 = try! MailboxPath(name: .init("box"), pathSeparator: nil)
        #expect(test1.name == .init("box"))
        #expect(test1.pathSeparator == nil)

        let test2 = try! MailboxPath(name: .init("box"))
        #expect(test2.name == .init("box"))
        #expect(test2.pathSeparator == nil)

        let test3 = try! MailboxPath(name: .init("box"), pathSeparator: "/")
        #expect(test3.name == .init("box"))
        #expect(test3.pathSeparator == "/")
    }

    @Test(
        "make sub-mailbox with display name",
        arguments: [
            SubMailboxFixture(
                path: try! .init(name: .init("box"), pathSeparator: "/"),
                newName: "£",
                expected: try! .init(name: .init("box/&AKM-"), pathSeparator: "/")
            )
        ]
    )
    func makeSubMailboxWithDisplayName(_ fixture: SubMailboxFixture) throws {
        #expect(try fixture.path.makeSubMailbox(displayName: fixture.newName) == fixture.expected)
    }

    @Test("make sub-mailbox enforces size limit")
    func makeSubMailboxEnforcesSizeLimit() {
        #expect(throws: MailboxTooBigError.self) {
            try MailboxPath(name: .init(ByteBuffer(string: String(repeating: "a", count: 999))), pathSeparator: "/")
                .makeSubMailbox(displayName: "1")
        }
    }

    @Test(
        "make root mailbox with display name",
        arguments: [
            RootMailboxFixture(
                displayName: "box2",
                pathSeparator: nil,
                expected: try! .init(name: .init("box2"), pathSeparator: nil)
            ),
            RootMailboxFixture(
                displayName: "£",
                pathSeparator: "/",
                expected: try! .init(name: .init("&AKM-"), pathSeparator: "/")
            )
        ]
    )
    func makeRootMailboxWithDisplayName(_ fixture: RootMailboxFixture) throws {
        #expect(
            try MailboxPath.makeRootMailbox(displayName: fixture.displayName, pathSeparator: fixture.pathSeparator)
                == fixture.expected
        )
    }

    @Test("make root mailbox enforces size limit")
    func makeRootMailboxEnforcesSizeLimit() {
        #expect(throws: MailboxTooBigError.self) {
            try MailboxPath.makeRootMailbox(displayName: String(repeating: "a", count: 1001))
        }
    }

    @Test(
        "splitting mailbox path components",
        arguments: [
            SplittingFixture(
                path: try! .init(name: .init("ABC"), pathSeparator: "B"),
                omitEmpty: true,
                expected: ["A", "C"]
            ),
            SplittingFixture(
                path: try! .init(name: .init("ABC"), pathSeparator: "D"),
                omitEmpty: true,
                expected: ["ABC"]
            ),
            SplittingFixture(
                path: try! .init(name: .init(""), pathSeparator: "D"),
                omitEmpty: true,
                expected: []
            ),
            SplittingFixture(
                path: try! .init(name: .init("some/real/mailbox"), pathSeparator: "/"),
                omitEmpty: true,
                expected: ["some", "real", "mailbox"]
            ),
            SplittingFixture(
                path: try! .init(name: .init("mailbox#test"), pathSeparator: "#"),
                omitEmpty: true,
                expected: ["mailbox", "test"]
            ),
            SplittingFixture(
                path: try! .init(name: .init("//test1//test2//"), pathSeparator: "/"),
                omitEmpty: true,
                expected: ["test1", "test2"]
            ),
            SplittingFixture(
                path: try! .init(name: .init("//test1//test2//"), pathSeparator: "/"),
                omitEmpty: false,
                expected: ["", "", "test1", "", "test2", "", ""]
            )
        ]
    )
    func splittingMailboxPathComponents(_ fixture: SplittingFixture) {
        #expect(fixture.path.displayStringComponents(omittingEmptySubsequences: fixture.omitEmpty) == fixture.expected)
    }

    @Test("create submailbox without path separator throws")
    func createSubmailboxWithoutPathSeparatorThrows() {
        let mailbox = try! MailboxPath(name: .inbox, pathSeparator: nil)
        #expect(throws: InvalidPathSeparatorError.self) {
            try mailbox.makeSubMailbox(displayName: "sub")
        }
    }

    @Test(
        "custom debug string convertible",
        arguments: [
            DebugStringFixture(sut: MailboxName.inbox, expected: "INBOX"),
            DebugStringFixture(sut: .init(ByteBuffer()), expected: ""),
            DebugStringFixture(sut: .init(ByteBuffer("Food")), expected: "Food"),
            DebugStringFixture(sut: .init(ByteBuffer("food")), expected: "food"),
            DebugStringFixture(sut: .init(ByteBuffer("FOOD")), expected: "FOOD"),
            DebugStringFixture(sut: .init(ByteBuffer("box/&AKM-")), expected: "box/&AKM-"),
            DebugStringFixture(sut: .init(ByteBuffer("a\u{11}b")), expected: "a\u{11}b"),
            DebugStringFixture(sut: .init(ByteBuffer("båd")), expected: "båd")
        ]
    )
    func customDebugStringConvertible(_ fixture: DebugStringFixture<MailboxName>) {
        fixture.check()
    }
}

@Suite("MailboxName")
struct MailboxNameTests {
    @Test("initialization normalizes INBOX to uppercase")
    func initializationNormalizesINBOXToUppercase() {
        let test1 = MailboxName("INBOX")
        #expect(test1.bytes == Array("INBOX".utf8))
        #expect(test1.isInbox)

        let test2 = MailboxName("inbox")
        #expect(test2.bytes == Array("INBOX".utf8))
        #expect(test2.isInbox)

        let test3 = MailboxName("Inbox")
        #expect(test3.bytes == Array("INBOX".utf8))
        #expect(test3.isInbox)

        let test4 = MailboxName("notinbox")
        #expect(test4.bytes == Array("notinbox".utf8))
        #expect(!test4.isInbox)

        let test5 = MailboxName("inBox2")
        #expect(test5.bytes == Array("inBox2".utf8))
        #expect(!test5.isInbox)
    }

    @Test("initialization with non-UTF8 bytes")
    func initializationWithNonUTF8Bytes() {
        let hexBytes: [UInt8] = [0x80]
        let test1 = MailboxName(.init(bytes: hexBytes))
        #expect(test1.bytes == hexBytes)
        #expect(!test1.isInbox)
    }

    @Test("equality comparison")
    func equalityComparison() {
        // Since we're using a custom implementation of Hashable.

        #expect(MailboxName("INBOX") == MailboxName("inbox"))
        #expect(MailboxName("AA") == MailboxName("AA"))
        #expect(MailboxName("A") != MailboxName("B"))
        #expect(MailboxName("Sent") != MailboxName("Drafts"))
    }

    @Test("hash value distribution")
    func hashValueDistribution() {
        // Since we're using a custom implementation of Hashable.

        func countBits(_ v: Int) -> Int {
            var value = UInt(bitPattern: v)
            var count = 0
            while value != 0 {
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

        #expect(countChangedBits("A", "B") >= 25)
        #expect(countChangedBits("A", "AA") >= 25)
        #expect(countChangedBits("INBOX", "Drafts") >= 25)
        #expect(countChangedBits("Sent", "Drafts") >= 25)
        #expect(countChangedBits("Sent", "sent") >= 25)
    }
}

// MARK: -

private struct SubMailboxFixture: Sendable, CustomTestStringConvertible {
    let path: MailboxPath
    let newName: String
    let expected: MailboxPath

    var testDescription: String { "\(path.name) + \(newName) -> \(expected.name)" }
}

private struct RootMailboxFixture: Sendable, CustomTestStringConvertible {
    let displayName: String
    let pathSeparator: Character?
    let expected: MailboxPath

    var testDescription: String { displayName }
}

private struct SplittingFixture: Sendable, CustomTestStringConvertible {
    let path: MailboxPath
    let omitEmpty: Bool
    let expected: [String]

    var testDescription: String { "\(path.name) omitEmpty:\(omitEmpty) -> \(expected)" }
}
