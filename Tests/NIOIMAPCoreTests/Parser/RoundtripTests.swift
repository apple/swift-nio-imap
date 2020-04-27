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

        let tests: [NIOIMAP.Command] = [
            // any
            .noop,
            .capability,
            .logout,

            // nonauth
            .starttls,
            .login("user", "password"),
            .authenticate("some", nil, ["abcd1234"]), // test single base64, spec is unclear about multiple
            .authenticate("some", .equals, ["abcd1234"]),
//
//            // auth
//            .create(.inbox),
//            .create(NIOIMAP.Mailbox("mailbox")),
//            .delete(.inbox),
//            .delete(NIOIMAP.Mailbox("mailbox")),
//            .examine(.inbox),
//            .examine(NIOIMAP.Mailbox("mailbox")),
//            .subscribe(.inbox),
//            .subscribe(NIOIMAP.Mailbox("mailbox")),
//            .unsubscribe(.inbox),
//            .unsubscribe(NIOIMAP.Mailbox("mailbox")),
//            .select(.inbox),
//            .select(NIOIMAP.Mailbox("mailbox")),
//            .rename(from: .inbox, to: .inbox),
//            .rename(from: NIOIMAP.Mailbox("test1"), to: NIOIMAP.Mailbox("test2")),
//            .append(to: .inbox, flags: [.answered], date: nil, size: 4), // APPEND single flag no date
//            .append(to: NIOIMAP.Mailbox("test1"), flags: [.answered, .deleted, .draft], date: nil, size: 4), // APPEND many flags no date
//            .append( // APPEND single flag and date
//                to: NIOIMAP.Mailbox("test2", #line),
//                flags: [.answered],
//                date: NIOIMAP.Date.DateTime(
//                    date: NIOIMAP.Date(day: 25, month: .jun, year: 1994),
//                    time: NIOIMAP.Date.Time(hour: 12, minute: 23, second: 34),
//                    zone: NIOIMAP.Date.TimeZone(0200)!
//                ),
//                size: 4
//            ),
//            .append(to: .inbox, flags: [], date: nil, size: 4), // APPEND no flags no date
//            .list(nil, .inbox, .pattern([]), nil), // LIST list-char
//            .list(nil, .inbox, .pattern([]), nil), // LIST string
//            .list(nil, NIOIMAP.Mailbox("bar"), .pattern([]), nil), // LIST string
//            .lsub(.inbox, "abcd"), // LSUB list-char
//            .lsub(.inbox, "\"something\""), // LSUB string
//            .lsub(NIOIMAP.Mailbox("bar"), "{3}\r\nfoo"), // LSUB string
//            .status(.inbox, [.messages]), // STATUS single
//            .status(NIOIMAP.Mailbox("foobar"), [.messages, .recent, .uidnext]), // STATUS many
//
//            // select
//            .check,
//            .close,
//            .expunge,
//            .copy([.single(2), .wildcard], .inbox),
//            .fetch([.wildcard], .all), // fetch commands can be complex, so we test several varieties to insure component interoperability
//            .fetch([.wildcard], .fast),
//            .fetch([.wildcard], .full),
//            .fetch([.single(5678)], .attributes([.uid, .flags, .internaldate, .envelope])),
//            .fetch([.single(5678)], .attributes([.flags, .body(structure: true)])),
//            .fetch([.single(5678)], .attributes([.flags, .bodySection(nil, NIOIMAP.Partial(left: 3, right: 4))])),
//            .fetch([.single(5678)], .attributes([.flags, .bodySection(.text(.header), NIOIMAP.Partial(left: 3, right: 4))])),
//            .fetch([.single(5678)], .attributes([.flags, .bodySection(.part([12, 34], text: .message(.headerFields(["some", "header"]))), NIOIMAP.Partial(left: 3, right: 4))])),
//            .store([.wildcard], .remove(silent: true, list: [.answered, .deleted])),
//            .store([.wildcard], .add(silent: false, list: [.draft, .extension("some")])),
//            .store([.wildcard], .other(silent: true, list: [.keyword("other")])),
//            .uid(.copy([.wildcard], .init("OtherBox"))),
//            .uid(.store([.wildcard], .add(silent: true, list: [.answered, .deleted, .draft]))),
//            .search(returnOptions: nil, program: NIOIMAP.SearchProgram(charset: nil, keys: [.all])),
//            .search(returnOptions: nil, program: NIOIMAP.SearchProgram(charset: "UTF8", keys: [.answered, .array([.deleted, .bcc("d.evans@apple.com")])]))
        ]

        var buffer = ByteBufferAllocator().buffer(capacity: 1)
        for (i, commandType) in tests.enumerated() {
            let tag = "\(i + 1)"
            let command = NIOIMAP.TaggedCommand(tag, commandType)
            buffer.writeCommand(command)
            buffer.writeString("\r\n") // required for commands that might terminate with a literal (e.g. append)
            do {
                let decoded = try NIOIMAP.GrammarParser.parseCommand(buffer: &buffer, tracker: .testTracker)
                XCTAssertEqual(command, decoded)
            } catch {
                XCTFail("\(error) - \(buffer.readString(length: buffer.readableBytesView.count)!)")
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
