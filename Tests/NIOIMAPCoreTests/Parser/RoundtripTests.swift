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
import NIOTestUtils

import XCTest

final class RoundtripTests: XCTestCase {}

// MARK: - Client command

extension RoundtripTests {
    func testClientRountrip() {
        self.measure {
            runClientTests()
        }
    }

    private func runClientTests() {
        // 1 AUTHENTICATE type\r\n1111\r\n2222\r\n

        let tests: [(Command, UInt)] = [
            (.noop, #line),
            (.capability, #line),
            (.logout, #line),
            (.starttls, #line),
            (.check, #line),
            (.close, #line),
            (.expunge, #line),

            (.login("user", "password"), #line),

            (.authenticate("some", nil, ["abcd1234"]), #line),
            (.authenticate("some", .equals, ["abcd1234"]), #line),

            (.create(.inbox, []), #line),
            (.create(MailboxName("mailbox"), []), #line),

            (.delete(.inbox), #line),
            (.delete(MailboxName("mailbox")), #line),

            (.examine(.inbox, []), #line),
            (.examine(MailboxName("mailbox"), []), #line),

            (.subscribe(.inbox), #line),
            (.subscribe(MailboxName("mailbox")), #line),

            (.unsubscribe(.inbox), #line),
            (.unsubscribe(MailboxName("mailbox")), #line),

            (.select(.inbox, []), #line),
            (.select(MailboxName("mailbox"), []), #line),

            (.rename(from: .inbox, to: .inbox, params: []), #line),
            (.rename(from: MailboxName("test1"), to: MailboxName("test2"), params: []), #line),

            (.append(to: .inbox, firstMessageMetadata: .options(.flagList([.answered], dateTime: nil, extensions: []), data: .byteCount(5))), #line),
            (.append(to: MailboxName("test1"), firstMessageMetadata: .options(.flagList([.answered, .deleted, .draft], dateTime: nil, extensions: []), data: .byteCount(5))), #line),

            (.list(nil, .inbox, .pattern(["pattern"]), []), #line),
            (.list(nil, MailboxName("bar"), .pattern(["pattern"]), []), #line),

            (.lsub(.inbox, "abcd"), #line),
            (.lsub(.inbox, "\"something\""), #line),
            (.lsub(MailboxName("bar"), "{3}\r\nfoo"), #line),

            (.status(.inbox, [.messages]), #line),
            (.status(MailboxName("foobar"), [.messages, .recent, .uidnext]), #line),

            (.copy([.single(2), .wildcard], .inbox), #line),

            (.fetch([.wildcard], .all, []), #line),
            (.fetch([.wildcard], .fast, []), #line),
            (.fetch([.wildcard], .full, []), #line),
            (.fetch([.single(5678)], .attributes([.uid, .flags, .internaldate, .envelope]), []), #line),
            (.fetch([.single(5678)], .attributes([.flags, .body(structure: true)]), []), #line),
            (.fetch([.single(5678)], .attributes([.flags, .bodySection(nil, Partial(left: 3, right: 4))]), []), #line),
            (.fetch([.single(5678)], .attributes([.flags, .bodySection(.text(.header), Partial(left: 3, right: 4))]), []), #line),
            (.fetch([.single(5678)], .attributes([.flags, .bodySection(.part([12, 34], text: .message(.headerFields(["some", "header"]))), Partial(left: 3, right: 4))]), []), #line),

            (.store([.wildcard], [], .remove(silent: true, list: [.answered, .deleted])), #line),
            (.store([.wildcard], [], .add(silent: true, list: [.draft, .extension("\\some")])), #line),
            (.store([.wildcard], [], .other(silent: true, list: [.keyword(.colorBit0)])), #line),

            (.uidCopy([.wildcard], .inbox), #line),

            (.uidStore([.wildcard], [], .add(silent: true, list: [.draft, .deleted, .answered])), #line),

            (.search(returnOptions: [.all], program: .charset(nil, keys: [.all])), #line),
        ]

        var buffer = ByteBufferAllocator().buffer(capacity: 1)
        for (i, test) in tests.enumerated() {
            let commandType = test.0
            let line = test.1
            let tag = "\(i + 1)"
            let command = TaggedCommand(tag, commandType)
            buffer.writeCommand(command)
            buffer.writeString("\r\n") // required for commands that might terminate with a literal (e.g. append)
            do {
                let decoded = try GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(command, decoded, line: line)
            } catch {
                XCTFail("\(error) - \(buffer.readString(length: buffer.readableBytesView.count)!)", line: line)
            }
            buffer.clear()
        }
    }
}

// MARK: - Server response

extension RoundtripTests {
    func testServerRountrip() {
        self.measure {
            runServerTests()
        }
    }

    private func runServerTests() {}
}
