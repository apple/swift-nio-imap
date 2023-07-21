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

class GrammarParser_Search_Tests: XCTestCase, _ParserTestHelpers {}

// MARK: - parseSearchCorrelator

extension GrammarParser_Search_Tests {
    func testParseSearchCorrelator() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchCorrelator,
            validInputs: [
                (" (TAG \"test1\")", "\r", SearchCorrelator(tag: "test1"), #line),
                (" (tag \"test2\")", "\r", SearchCorrelator(tag: "test2"), #line),
                (
                    " (TAG \"test1\" MAILBOX \"mb\" UIDVALIDITY 5)", "\r",
                    SearchCorrelator(tag: "test1", mailbox: MailboxName("mb"), uidValidity: 5), #line
                ),
                (
                    " (MAILBOX \"mb\" UIDVALIDITY 5 TAG \"test1\")", "\r",
                    SearchCorrelator(tag: "test1", mailbox: MailboxName("mb"), uidValidity: 5), #line
                ),
            ],
            parserErrorInputs: [
                (" (TAG \"test1\" MAILBOX \"mb\" )", "\r", #line),
                (" (TAG \"test1\" MAILBOX \"mb\")", "\r", #line),
                (" (TAG \"test1\" MAILBOX \"mb\" MAILBOX \"mb\")", "\r", #line),
                (" (MAILBOX \"mb\")", "\r", #line),
                (" (UIDVALIDITY 5)", "\r", #line),
            ],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-criteria` parseSearchCriteria

extension GrammarParser_Search_Tests {
    func testParseSearchCriteria() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchCriteria,
            validInputs: [
                ("ALL", "\r", [.all], #line),
                ("ALL ANSWERED DELETED", "\r", [.all, .answered, .deleted], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-key` parseSearchKey

extension GrammarParser_Search_Tests {
    func testParseSearchKey() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchKey,
            validInputs: [
                ("ALL", "\r", .all, #line),
                ("ANSWERED", "\r", .answered, #line),
                ("DELETED", "\r", .deleted, #line),
                ("FLAGGED", "\r", .flagged, #line),
                ("NEW", "\r", .new, #line),
                ("OLD", "\r", .old, #line),
                ("RECENT", "\r", .recent, #line),
                ("SEEN", "\r", .seen, #line),
                ("UNANSWERED", "\r", .unanswered, #line),
                ("UNDELETED", "\r", .undeleted, #line),
                ("UNFLAGGED", "\r", .unflagged, #line),
                ("UNSEEN", "\r", .unseen, #line),
                ("UNDRAFT", "\r", .undraft, #line),
                ("DRAFT", "\r", .draft, #line),
                ("ON 25-jun-1994", "\r", .on(IMAPCalendarDay(year: 1994, month: 6, day: 25)!), #line),
                ("SINCE 01-jan-2001", "\r", .since(IMAPCalendarDay(year: 2001, month: 1, day: 1)!), #line),
                ("SENTON 02-jan-2002", "\r", .sentOn(IMAPCalendarDay(year: 2002, month: 1, day: 2)!), #line),
                ("SENTBEFORE 03-jan-2003", "\r", .sentBefore(IMAPCalendarDay(year: 2003, month: 1, day: 3)!), #line),
                ("SENTSINCE 04-jan-2004", "\r", .sentSince(IMAPCalendarDay(year: 2004, month: 1, day: 4)!), #line),
                ("BEFORE 05-jan-2005", "\r", .before(IMAPCalendarDay(year: 2005, month: 1, day: 5)!), #line),
                ("LARGER 1234", "\r", .messageSizeLarger(1234), #line),
                ("SMALLER 5678", "\r", .messageSizeSmaller(5678), #line),
                ("BCC data1", "\r", .bcc("data1"), #line),
                ("BODY data2", "\r", .body("data2"), #line),
                ("CC data3", "\r", .cc("data3"), #line),
                ("FROM data4", "\r", .from("data4"), #line),
                ("SUBJECT data5", "\r", .subject("data5"), #line),
                ("TEXT data6", "\r", .text("data6"), #line),
                ("TO data7", "\r", .to("data7"), #line),
                ("KEYWORD key1", "\r", .keyword(Flag.Keyword("key1")!), #line),
                ("HEADER some value", "\r", .header("some", "value"), #line),
                ("UNKEYWORD key2", "\r", .unkeyword(Flag.Keyword("key2")!), #line),
                ("NOT LARGER 1234", "\r", .not(.messageSizeLarger(1234)), #line),
                ("OR LARGER 6 SMALLER 4", "\r", .or(.messageSizeLarger(6), .messageSizeSmaller(4)), #line),
                ("UID 2:4", "\r", .uid(.set(MessageIdentifierSetNonEmpty(set: MessageIdentifierSet<UID>(2 ... 4))!)), #line),
                ("2:4", "\r", .sequenceNumbers(.set([2 ... 4])), #line),
                ("(LARGER 1)", "\r", .messageSizeLarger(1), #line),
                ("(LARGER 1 SMALLER 5 KEYWORD hello)", "\r", .and([.messageSizeLarger(1), .messageSizeSmaller(5), .keyword(Flag.Keyword("hello")!)]), #line),
                ("YOUNGER 34", "\r", .younger(34), #line),
                ("OLDER 45", "\r", .older(45), #line),
                ("FILTER something", "\r", .filter("something"), #line),
                ("MODSEQ 5", "\r", .modificationSequence(.init(extensions: [:], sequenceValue: 5)), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }

    func testParseSearchKey_array_none_invalid() {
        var buffer = TestUtilities.makeParseBuffer(for: "()")
        XCTAssertThrowsError(try GrammarParser().parseSearchKey(buffer: &buffer, tracker: .testTracker)) { e in
            XCTAssertTrue(e is ParserError)
        }
    }
}

// MARK: - `search-ret-data-ext` parseSearchReturnDataExtension

extension GrammarParser_Search_Tests {
    // the spec is ambiguous when parsing `tagged-ext-simple`, in that a "number" is also a "sequence-set"
    // our parser gives priority to "sequence-set"
    func testParseSearchReturnDataExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnDataExtension,
            validInputs: [
                ("modifier 64", "\r", .init(key: "modifier", value: .sequence(.set([64]))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseSearchModifierSequence

extension GrammarParser_Search_Tests {
    func testParseSearchModifierSequence() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchModificationSequence,
            validInputs: [
                ("MODSEQ 4", " ", .init(extensions: [:], sequenceValue: 4), #line),
                (
                    "MODSEQ \"/flags/\\\\Answered\" priv 4",
                    " ",
                    .init(extensions: [.init(flag: .answered): .private], sequenceValue: 4),
                    #line
                ),
                (
                    "MODSEQ \"/flags/\\\\Answered\" priv \"/flags/\\\\Seen\" shared 4",
                    " ",
                    .init(extensions: [
                        .init(flag: .answered): .private,
                        .init(flag: .seen): .shared,
                    ], sequenceValue: 4),
                    #line
                ),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - parseSearchModifierSequenceExtension

extension GrammarParser_Search_Tests {
    func testParseSearchModifierSequenceExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchModificationSequenceExtension,
            validInputs: [
                (" \"/flags/\\\\Seen\" all", "", .init(key: .init(flag: .seen), value: .all), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-data` parseSearchReturnData

extension GrammarParser_Search_Tests {
    func testParseSearchReturnData() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnData,
            validInputs: [
                ("MIN 1", "\r", .min(1), #line),
                ("MAX 2", "\r", .max(2), #line),
                ("ALL 3", "\r", .all(.set([3])), #line),
                ("ALL 3,4,5", "\r", .all(.set([3, 4, 5])), #line),
                ("COUNT 4", "\r", .count(4), #line),
                ("MODSEQ 4", "\r", .modificationSequence(4), #line),
                ("modifier 5", "\r", .dataExtension(.init(key: "modifier", value: .sequence(.set([5])))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `ret-data-partial` parseSearchReturnData_partial

extension GrammarParser_Search_Tests {
    func testParseSearchReturnDataPartial() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnData_partial,
            validInputs: [
                ("PARTIAL (23500:24000 67,100:102)", "\r", .partial(.first(23_500 ... 24_000), [67, 100 ... 102]), #line),
                ("PARTIAL (-55:-700 NIL)", "\r", .partial(.last(55 ... 700), []), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opt` parseSearchReturnOption

extension GrammarParser_Search_Tests {
    func testParseSearchReturnOption() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnOption,
            validInputs: [
                ("MIN", "\r", .min, #line),
                ("min", "\r", .min, #line),
                ("mIn", "\r", .min, #line),
                ("MAX", "\r", .max, #line),
                ("max", "\r", .max, #line),
                ("mAx", "\r", .max, #line),
                ("ALL", "\r", .all, #line),
                ("all", "\r", .all, #line),
                ("AlL", "\r", .all, #line),
                ("COUNT", "\r", .count, #line),
                ("count", "\r", .count, #line),
                ("COunt", "\r", .count, #line),
                ("SAVE", "\r", .save, #line),
                ("save", "\r", .save, #line),
                ("saVE", "\r", .save, #line),
                ("PARTIAL 23500:24000", "\r", .partial(.first(23_500 ... 24_000)), #line),
                ("partial -1:-100", "\r", .partial(.last(1 ... 100)), #line),
                ("modifier", "\r", .optionExtension(.init(key: "modifier", value: nil)), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opts` parseSearchReturnOptions

extension GrammarParser_Search_Tests {
    func testParseSearchReturnOptions() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnOptions,
            validInputs: [
                (" RETURN (ALL)", "\r", [.all], #line),
                (" RETURN (MIN MAX COUNT)", "\r", [.min, .max, .count], #line),
                (" RETURN (m1 m2)", "\r", [
                    .optionExtension(.init(key: "m1", value: nil)),
                    .optionExtension(.init(key: "m2", value: nil)),
                ], #line),
                (" RETURN (PARTIAL 23500:24000)", "\r", [.partial(.first(23_500 ... 24_000))], #line),
                (" RETURN (MIN PARTIAL -1:-100 MAX)", "\r", [.min, .partial(.last(1 ... 100)), .max], #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: []
        )
    }
}

// MARK: - `search-ret-opt-ext` parseSearchReturnOptionExtension

extension GrammarParser_Search_Tests {
    func testParseSearchReturnOptionExtension() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchReturnOptionExtension,
            validInputs: [
                ("modifier", "\r", .init(key: "modifier", value: nil), #line),
                ("modifier 4", "\r", .init(key: "modifier", value: .sequence(.set([4]))), #line),
            ],
            parserErrorInputs: [],
            incompleteMessageInputs: [
                ("modifier ", "", #line),
            ]
        )
    }
}

// MARK: - parseSearchSortModifierSequence

extension GrammarParser_Search_Tests {
    func testParseSearchSortModifierSequence() {
        self.iterateTests(
            testFunction: GrammarParser().parseSearchSortModificationSequence,
            validInputs: [
                ("(MODSEQ 123)", "\r", 123, #line),
            ],
            parserErrorInputs: [
                ("(MODSEQ a)", "", #line),
            ],
            incompleteMessageInputs: [
                ("(MODSEQ ", "", #line),
                ("(MODSEQ 111", "", #line),
            ]
        )
    }
}
