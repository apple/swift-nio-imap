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

@testable import IMAPToolLib
import Foundation
import NIO
import NIOIMAP
import Testing

@Suite("Search Predicate Tests")
private enum SearchPredicateTests {
    struct CreateSearchKeyFixture: Sendable, CustomTestStringConvertible {
        var input: SearchKey.Predicate
        var expected: SearchKey
        var date = Date(timeIntervalSinceReferenceDate: 782_115_211)
        var timeZone = TimeZone(secondsFromGMT: 120)!

        var testDescription: String { "\(input)" }
    }

    @Test(arguments: [
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(),
            expected: .all
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(olderThanDays: 7),
            expected: .sentBefore(
                IMAPCalendarDay(
                    year: 2025,
                    month: 10,
                    day: 7
                )!
            )
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(newerThanDays: 3),
            expected: .sentSince(
                IMAPCalendarDay(
                    year: 2025,
                    month: 10,
                    day: 11
                )!
            )
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(subject: "test"),
            expected: .subject(ByteBuffer(string: "test"))
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(from: "alice@example.com"),
            expected: .from(ByteBuffer(string: "alice@example.com"))
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(to: "bob@example.com"),
            expected: .to(ByteBuffer(string: "bob@example.com"))
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(cc: "charlie@example.com"),
            expected: .cc(ByteBuffer(string: "charlie@example.com"))
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(text: "important"),
            expected: .text(ByteBuffer(string: "important"))
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(
                messageSizeSmallerThan: 1024
            ),
            expected: .messageSizeSmaller(1024)
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(
                messageSizeLargerThan: 8192
            ),
            expected: .messageSizeLarger(8192)
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(messageID: "<msg123@example.com>"),
            expected: .messageID("<msg123@example.com>")
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(emailID: "email-id-123"),
            expected: .emailID("email-id-123")
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(threadID: "thread-id-456"),
            expected: .threadID("thread-id-456")
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(flagsSet: [.answered]),
            expected: .answered
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(flagsNotSet: [.seen]),
            expected: .unseen
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(
                olderThanDays: 7,
                subject: "test"
            ),
            expected: .and([
                .sentBefore(
                    IMAPCalendarDay(
                        year: 2025,
                        month: 10,
                        day: 7
                    )!
                ),
                .subject(ByteBuffer(string: "test")),
            ])
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(
                from: "alice@example.com",
                flagsSet: [.flagged]
            ),
            expected: .and([
                .from(ByteBuffer(string: "alice@example.com")),
                .flagged,
            ])
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(
                messageSizeLargerThan: 1024,
                flagsNotSet: [.deleted]
            ),
            expected: .and([
                .messageSizeLarger(1024),
                .undeleted,
            ])
        ),
        CreateSearchKeyFixture(
            input: SearchKey.Predicate(
                flagsSet: [
                    NIOIMAP.Flag("$MailFlagBit0"),
                    .flagged,
                ],
                flagsNotSet: [
                    NIOIMAP.Flag("$MailFlagBit1"),
                    NIOIMAP.Flag("$MailFlagBit2"),
                ]
            ),
            expected: .and([
                .keyword(Flag.Keyword("$MailFlagBit0")!),
                .flagged,
                .not(.keyword(Flag.Keyword("$MailFlagBit1")!)),
                .not(.keyword(Flag.Keyword("$MailFlagBit2")!)),
            ])
        ),
    ])
    static func `make search key`(
        fixture: CreateSearchKeyFixture
    ) throws {
        let actual = try SearchKey(
            fixture.input,
            now: fixture.date,
            timeZone: fixture.timeZone
        )
        #expect(
            actual == fixture.expected
        )
    }

    struct FlagSearchKeyFixture: Sendable, CustomTestStringConvertible {
        var input: NIOIMAP.Flag
        var expected: SearchKey
        var expectedInverted: SearchKey

        var testDescription: String {
            let d = String(input)
            return d.isEmpty ? "/" : d
        }
    }

    @Test(arguments: [
        FlagSearchKeyFixture(
            input: .answered,
            expected: .answered,
            expectedInverted: .unanswered
        ),
        FlagSearchKeyFixture(
            input: .flagged,
            expected: .flagged,
            expectedInverted: .unflagged
        ),
        FlagSearchKeyFixture(
            input: .deleted,
            expected: .deleted,
            expectedInverted: .undeleted
        ),
        FlagSearchKeyFixture(
            input: .seen,
            expected: .seen,
            expectedInverted: .unseen
        ),
        FlagSearchKeyFixture(
            input: NIOIMAP.Flag("$MailFlagBit0"),
            expected: .keyword(Flag.Keyword("$MailFlagBit0")!),
            expectedInverted: .not(.keyword(Flag.Keyword("$MailFlagBit0")!))
        ),
        FlagSearchKeyFixture(
            input: NIOIMAP.Flag("$MailFlagBit2"),
            expected: .keyword(Flag.Keyword("$MailFlagBit2")!),
            expectedInverted: .not(.keyword(Flag.Keyword("$MailFlagBit2")!))
        ),
    ])
    static func `make search key from flag`(
        fixture: FlagSearchKeyFixture
    ) throws {
        #expect(try SearchKey(flag: fixture.input) == fixture.expected)
        #expect(try SearchKey(notFlag: fixture.input) == fixture.expectedInverted)
    }
}
