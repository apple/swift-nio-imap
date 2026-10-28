//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import ArgumentParser
@testable import IMAPToolLib
import Foundation
import NIO
import NIOIMAP
import Testing

@Suite("SearchMessagesCommand Tests")
private enum SearchMessagesCommandPredicateTests {
    struct ParseFixture: Sendable, CustomTestStringConvertible {
        var arguments: [String]
        var expected: Expected

        enum Expected: Sendable {
            case parse(SearchKey.Predicate)
            case fail(String)
        }

        var testDescription: String { arguments.joined(separator: " ") }
    }

    @Test(arguments: [
        ParseFixture(
            arguments: ["--from", "foo"],
            expected: .parse(
                SearchKey.Predicate(
                    from: "foo"
                )
            )
        ),
        ParseFixture(
            arguments: ["--to", "bar"],
            expected: .parse(
                SearchKey.Predicate(
                    to: "bar"
                )
            )
        ),
        ParseFixture(
            arguments: ["--cc", "baz"],
            expected: .parse(
                SearchKey.Predicate(
                    cc: "baz"
                )
            )
        ),
        ParseFixture(
            arguments: ["--subject", "test subject"],
            expected: .parse(
                SearchKey.Predicate(
                    subject: "test subject"
                )
            )
        ),
        ParseFixture(
            arguments: ["--text", "search text"],
            expected: .parse(
                SearchKey.Predicate(
                    text: "search text"
                )
            )
        ),
        ParseFixture(
            arguments: ["--older-than-days", "10"],
            expected: .parse(
                SearchKey.Predicate(
                    olderThanDays: 10
                )
            )
        ),
        ParseFixture(
            arguments: ["--newer-than-days", "5"],
            expected: .parse(
                SearchKey.Predicate(
                    newerThanDays: 5
                )
            )
        ),
        ParseFixture(
            arguments: ["--message-size-smaller-than", "1000"],
            expected: .parse(
                SearchKey.Predicate(
                    messageSizeSmallerThan: 1000
                )
            )
        ),
        ParseFixture(
            arguments: ["--message-size-larger-than", "500"],
            expected: .parse(
                SearchKey.Predicate(
                    messageSizeLargerThan: 500
                )
            )
        ),
        ParseFixture(
            arguments: ["--message-id", "<test@example.com>"],
            expected: .parse(
                SearchKey.Predicate(
                    messageID: MessageID("<test@example.com>")
                )
            )
        ),
        ParseFixture(
            arguments: ["--email-id", "test123"],
            expected: .parse(
                SearchKey.Predicate(
                    emailID: EmailID("test123")
                )
            )
        ),
        ParseFixture(
            arguments: ["--thread-id", "thread456"],
            expected: .parse(
                SearchKey.Predicate(
                    threadID: ThreadID("thread456")
                )
            )
        ),
        ParseFixture(
            arguments: ["--flag", "seen"],
            expected: .parse(
                SearchKey.Predicate(
                    flagsSet: [.seen]
                )
            )
        ),
        ParseFixture(
            arguments: ["--flag", "red"],
            expected: .parse(
                SearchKey.Predicate(
                    flagsSet: [.flagged],
                    flagsNotSet: [.mailFlagBit0, .mailFlagBit1, .mailFlagBit2]
                )
            )
        ),
        ParseFixture(
            arguments: ["--flag", "orange"],
            expected: .parse(
                SearchKey.Predicate(
                    flagsSet: [.flagged, .mailFlagBit0],
                    flagsNotSet: [.mailFlagBit1, .mailFlagBit2]
                )
            )
        ),
        ParseFixture(
            arguments: ["--flag", "seen", "--flag", "deleted"],
            expected: .parse(
                SearchKey.Predicate(
                    flagsSet: [.seen, .deleted]
                )
            )
        ),
        ParseFixture(
            arguments: ["--flag", "red", "--flag", "orange"],
            expected: .fail("Error: Invalid combination of flags {red, orange}")
        ),
        ParseFixture(
            arguments: ["--flag", "red", "--flag", "orange", "--flag", "answered"],
            expected: .fail("Error: Invalid combination of flags {red, orange}")
        ),
        ParseFixture(
            arguments: ["--from", "sender@example.com", "--to", "recipient@example.com", "--flag", "seen"],
            expected: .parse(
                SearchKey.Predicate(
                    from: "sender@example.com",
                    to: "recipient@example.com",
                    flagsSet: [.seen]
                )
            )
        ),
        ParseFixture(
            arguments: ["--from", "boss@example.com", "--subject", "urgent", "--older-than-days", "7"],
            expected: .parse(
                SearchKey.Predicate(
                    olderThanDays: 7,
                    subject: "urgent",
                    from: "boss@example.com"
                )
            )
        ),
        ParseFixture(
            arguments: ["--from", "newsletter@example.com", "--message-size-larger-than", "1000000"],
            expected: .parse(
                SearchKey.Predicate(
                    from: "newsletter@example.com",
                    messageSizeLargerThan: 1_000_000
                )
            )
        ),
        ParseFixture(
            arguments: [
                "--text", "verification code", "--newer-than-days", "1", "--message-size-smaller-than", "5000",
            ],
            expected: .parse(
                SearchKey.Predicate(
                    newerThanDays: 1,
                    text: "verification code",
                    messageSizeSmallerThan: 5000
                )
            )
        ),
        ParseFixture(
            arguments: [
                "--from", "team@example.com", "--to", "me@example.com", "--cc", "manager@example.com", "--subject",
                "project update",
            ],
            expected: .parse(
                SearchKey.Predicate(
                    subject: "project update",
                    from: "team@example.com",
                    to: "me@example.com",
                    cc: "manager@example.com"
                )
            )
        ),
        ParseFixture(
            arguments: ["--subject", "invoice", "--text", "payment due", "--newer-than-days", "30"],
            expected: .parse(
                SearchKey.Predicate(
                    newerThanDays: 30,
                    subject: "invoice",
                    text: "payment due"
                )
            )
        ),
        ParseFixture(
            arguments: ["--thread-id", "thread789", "--flag", "seen", "--flag", "answered"],
            expected: .parse(
                SearchKey.Predicate(
                    threadID: ThreadID("thread789"),
                    flagsSet: [.seen, .answered]
                )
            )
        ),
        ParseFixture(
            arguments: ["--older-than-days", "365", "--message-size-larger-than", "10000000", "--flag", "seen"],
            expected: .parse(
                SearchKey.Predicate(
                    olderThanDays: 365,
                    messageSizeLargerThan: 10_000_000,
                    flagsSet: [.seen]
                )
            )
        ),
        ParseFixture(
            arguments: ["--older-than-days", "10", "--newer-than-days", "20"],
            expected: .parse(
                SearchKey.Predicate(
                    olderThanDays: 10,
                    newerThanDays: 20,
                )
            )
        ),
        ParseFixture(
            arguments: ["--older-than-days", "20", "--newer-than-days", "10"],
            expected: .fail("Error: Messages can not be older than 20 and newer than 10 at the same time.")
        ),
    ])
    static func parse(
        fixture: ParseFixture
    ) throws {
        switch fixture.expected {
        case .parse(let expected):
            let commandPredicate = try SearchMessagesCommand.Predicate.parse(fixture.arguments)
            let p = try SearchKey.Predicate(commandPredicate)
            #expect(p.olderThanDays == expected.olderThanDays)
            #expect(p.newerThanDays == expected.newerThanDays)
            #expect(p.subject == expected.subject)
            #expect(p.from == expected.from)
            #expect(p.to == expected.to)
            #expect(p.cc == expected.cc)
            #expect(p.text == expected.text)
            #expect(p.messageSizeSmallerThan == expected.messageSizeSmallerThan)
            #expect(p.messageSizeLargerThan == expected.messageSizeLargerThan)
            #expect(p.messageID == expected.messageID)
            #expect(p.emailID == expected.emailID)
            #expect(p.threadID == expected.threadID)
            #expect(p.flagsSet == expected.flagsSet)
            #expect(p.flagsNotSet == expected.flagsNotSet)
        case .fail(let expected):
            #expect(
                performing: {
                    let commandPredicate = try SearchMessagesCommand.Predicate.parse(fixture.arguments)
                    _ = try SearchKey.Predicate(commandPredicate)
                },
                throws: {
                    #expect(
                        firstLineOfErrorMessage(for: $0)
                            == expected
                    )
                    return true
                }
            )
        }
    }
}
