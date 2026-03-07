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
@_spi(NIOIMAPInternal) @testable import NIOIMAPCore
import Testing

@Suite("SearchKey")
struct SearchKeyTests {
    @Test(arguments: [
        EncodeFixture.searchKey(.all, "ALL"),
        EncodeFixture.searchKey(.answered, "ANSWERED"),
        EncodeFixture.searchKey(.deleted, "DELETED"),
        EncodeFixture.searchKey(.flagged, "FLAGGED"),
        EncodeFixture.searchKey(.new, "NEW"),
        EncodeFixture.searchKey(.old, "OLD"),
        EncodeFixture.searchKey(.recent, "RECENT"),
        EncodeFixture.searchKey(.seen, "SEEN"),
        EncodeFixture.searchKey(.unanswered, "UNANSWERED"),
        EncodeFixture.searchKey(.undeleted, "UNDELETED"),
        EncodeFixture.searchKey(.unflagged, "UNFLAGGED"),
        EncodeFixture.searchKey(.unseen, "UNSEEN"),
        EncodeFixture.searchKey(.draft, "DRAFT"),
        EncodeFixture.searchKey(.undraft, "UNDRAFT"),
        EncodeFixture.searchKey(.bcc("hello@hello.co.uk"), "BCC \"hello@hello.co.uk\""),
        EncodeFixture.searchKey(.before(IMAPCalendarDay(year: 1994, month: 6, day: 25)!), "BEFORE 25-Jun-1994"),
        EncodeFixture.searchKey(.body("some body"), "BODY \"some body\""),
        EncodeFixture.searchKey(.cc("tim@apple.com"), "CC \"tim@apple.com\""),
        EncodeFixture.searchKey(.from("tim@apple.com"), "FROM \"tim@apple.com\""),
        EncodeFixture.searchKey(.keyword(Flag.Keyword(unchecked: "somekeyword")), "KEYWORD somekeyword"),
        EncodeFixture.searchKey(.on(IMAPCalendarDay(year: 1999, month: 9, day: 16)!), "ON 16-Sep-1999"),
        EncodeFixture.searchKey(.since(IMAPCalendarDay(year: 1984, month: 1, day: 17)!), "SINCE 17-Jan-1984"),
        EncodeFixture.searchKey(.subject("some subject"), "SUBJECT \"some subject\""),
        EncodeFixture.searchKey(.text("some text"), "TEXT \"some text\""),
        EncodeFixture.searchKey(.to("theboss@apple.com"), "TO \"theboss@apple.com\""),
        EncodeFixture.searchKey(.unkeyword(Flag.Keyword(unchecked: "nokeyword")), "UNKEYWORD nokeyword"),
        EncodeFixture.searchKey(.header("header", "value"), "HEADER \"header\" \"value\""),
        EncodeFixture.searchKey(.messageSizeLarger(333), "LARGER 333"),
        EncodeFixture.searchKey(.not(.messageSizeLarger(444)), "NOT LARGER 444"),
        EncodeFixture.searchKey(.or(.messageSizeSmaller(444), .messageSizeLarger(666)), "OR SMALLER 444 LARGER 666"),
        EncodeFixture.searchKey(.sentOn(IMAPCalendarDay(year: 2018, month: 12, day: 7)!), "SENTON 7-Dec-2018"),
        EncodeFixture.searchKey(.sentBefore(IMAPCalendarDay(year: 2018, month: 12, day: 7)!), "SENTBEFORE 7-Dec-2018"),
        EncodeFixture.searchKey(.sentSince(IMAPCalendarDay(year: 2018, month: 12, day: 7)!), "SENTSINCE 7-Dec-2018"),
        EncodeFixture.searchKey(.messageSizeSmaller(555), "SMALLER 555"),
        EncodeFixture.searchKey(
            .uid(.set(MessageIdentifierSetNonEmpty(set: MessageIdentifierSet<UID>(333...444))!)),
            "UID 333:444"
        ),
        EncodeFixture.searchKey(.sequenceNumbers(.range(1...222)), "1:222"),
        EncodeFixture.searchKey(.sequenceNumbers(.range(222...)), "222:*"),
        EncodeFixture.searchKey(.and([]), "()"),
        EncodeFixture.searchKey(.and([.messageSizeSmaller(444), .messageSizeLarger(333)]), "SMALLER 444 LARGER 333"),
        EncodeFixture.searchKey(.filter("name"), "FILTER name"),
        EncodeFixture.searchKey(.modificationSequence(.init(extensions: [:], sequenceValue: 5)), "MODSEQ 5"),
        EncodeFixture.searchKey(.uidAfter(.id(222)), "UIDAFTER 222"),
        EncodeFixture.searchKey(.uidAfter(.lastCommand), "UIDAFTER $"),
        EncodeFixture.searchKey(.uidBefore(.id(62_659)), "UIDBEFORE 62659"),
        EncodeFixture.searchKey(.uidBefore(.lastCommand), "UIDBEFORE $"),
        EncodeFixture.searchKey(.and([.messageSizeSmaller(444)]), "SMALLER 444"),
        EncodeFixture.searchKey(.not(.and([.messageSizeSmaller(444)])), "NOT SMALLER 444"),
        EncodeFixture.searchKey(
            .not(.and([.messageSizeSmaller(444), .messageSizeLarger(333)])),
            "NOT (SMALLER 444 LARGER 333)"
        ),
        EncodeFixture.searchKey(
            .or(.not(.messageSizeSmaller(444)), .messageSizeLarger(333)),
            "OR (NOT SMALLER 444) LARGER 333"
        ),
        EncodeFixture.searchKey(
            .or(.not(.and([.messageSizeSmaller(444), .messageSizeLarger(333)])), .undeleted),
            "OR (NOT (SMALLER 444 LARGER 333)) UNDELETED"
        ),
        EncodeFixture.searchKey(
            .and([.or(.messageSizeSmaller(444), .messageSizeLarger(333)), .undeleted]),
            "(OR SMALLER 444 LARGER 333) UNDELETED"
        ),
        EncodeFixture.searchKey(.emailID(.init("123-456-789")!), "EMAILID 123-456-789"),
        EncodeFixture.searchKey(.threadID(.init("123-456-789")!), "THREADID 123-456-789"),
        EncodeFixture.searchKey(.younger(34), "YOUNGER 34"),
        EncodeFixture.searchKey(.older(45), "OLDER 45"),
    ])
    func encode(_ fixture: EncodeFixture<SearchKey>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.searchKey("ALL", expected: .success(.all)),
        ParseFixture.searchKey("ANSWERED", expected: .success(.answered)),
        ParseFixture.searchKey("DELETED", expected: .success(.deleted)),
        ParseFixture.searchKey("FLAGGED", expected: .success(.flagged)),
        ParseFixture.searchKey("NEW", expected: .success(.new)),
        ParseFixture.searchKey("OLD", expected: .success(.old)),
        ParseFixture.searchKey("RECENT", expected: .success(.recent)),
        ParseFixture.searchKey("SEEN", expected: .success(.seen)),
        ParseFixture.searchKey("UNANSWERED", expected: .success(.unanswered)),
        ParseFixture.searchKey("UNDELETED", expected: .success(.undeleted)),
        ParseFixture.searchKey("UNFLAGGED", expected: .success(.unflagged)),
        ParseFixture.searchKey("UNSEEN", expected: .success(.unseen)),
        ParseFixture.searchKey("UNDRAFT", expected: .success(.undraft)),
        ParseFixture.searchKey("DRAFT", expected: .success(.draft)),
        ParseFixture.searchKey(
            "ON 25-jun-1994",
            expected: .success(.on(IMAPCalendarDay(year: 1994, month: 6, day: 25)!))
        ),
        ParseFixture.searchKey(
            "SINCE 01-jan-2001",
            expected: .success(.since(IMAPCalendarDay(year: 2001, month: 1, day: 1)!))
        ),
        ParseFixture.searchKey(
            "SENTON 02-jan-2002",
            expected: .success(.sentOn(IMAPCalendarDay(year: 2002, month: 1, day: 2)!))
        ),
        ParseFixture.searchKey(
            "SENTBEFORE 03-jan-2003",
            expected: .success(.sentBefore(IMAPCalendarDay(year: 2003, month: 1, day: 3)!))
        ),
        ParseFixture.searchKey(
            "SENTSINCE 04-jan-2004",
            expected: .success(.sentSince(IMAPCalendarDay(year: 2004, month: 1, day: 4)!))
        ),
        ParseFixture.searchKey(
            "BEFORE 05-jan-2005",
            expected: .success(.before(IMAPCalendarDay(year: 2005, month: 1, day: 5)!))
        ),
        ParseFixture.searchKey("LARGER 1234", expected: .success(.messageSizeLarger(1234))),
        ParseFixture.searchKey("SMALLER 5678", expected: .success(.messageSizeSmaller(5678))),
        ParseFixture.searchKey("BCC data1", expected: .success(.bcc("data1"))),
        ParseFixture.searchKey("BODY data2", expected: .success(.body("data2"))),
        ParseFixture.searchKey("CC data3", expected: .success(.cc("data3"))),
        ParseFixture.searchKey("FROM data4", expected: .success(.from("data4"))),
        ParseFixture.searchKey("SUBJECT data5", expected: .success(.subject("data5"))),
        ParseFixture.searchKey("TEXT data6", expected: .success(.text("data6"))),
        ParseFixture.searchKey("TO data7", expected: .success(.to("data7"))),
        ParseFixture.searchKey("KEYWORD key1", expected: .success(.keyword(Flag.Keyword("key1")!))),
        ParseFixture.searchKey("HEADER some value", expected: .success(.header("some", "value"))),
        ParseFixture.searchKey("UNKEYWORD key2", expected: .success(.unkeyword(Flag.Keyword("key2")!))),
        ParseFixture.searchKey("NOT LARGER 1234", expected: .success(.not(.messageSizeLarger(1234)))),
        ParseFixture.searchKey(
            "OR LARGER 6 SMALLER 4",
            expected: .success(.or(.messageSizeLarger(6), .messageSizeSmaller(4)))
        ),
        ParseFixture.searchKey(
            "UID 2:4",
            expected: .success(.uid(.set(MessageIdentifierSetNonEmpty(set: MessageIdentifierSet<UID>(2...4))!)))
        ),
        ParseFixture.searchKey("UIDAFTER 33875", expected: .success(.uidAfter(.id(33_875)))),
        ParseFixture.searchKey("UIDAFTER $", expected: .success(.uidAfter(.lastCommand))),
        ParseFixture.searchKey("UIDBEFORE 44371", expected: .success(.uidBefore(.id(44_371)))),
        ParseFixture.searchKey("UIDBEFORE $", expected: .success(.uidBefore(.lastCommand))),
        ParseFixture.searchKey("2:4", expected: .success(.sequenceNumbers(.set([2...4])))),
        ParseFixture.searchKey("(LARGER 1)", expected: .success(.messageSizeLarger(1))),
        ParseFixture.searchKey(
            "(LARGER 1 SMALLER 5 KEYWORD hello)",
            expected: .success(.and([.messageSizeLarger(1), .messageSizeSmaller(5), .keyword(Flag.Keyword("hello")!)]))
        ),
        ParseFixture.searchKey("YOUNGER 34", expected: .success(.younger(34))),
        ParseFixture.searchKey("OLDER 45", expected: .success(.older(45))),
        ParseFixture.searchKey("FILTER something", expected: .success(.filter("something"))),
        ParseFixture.searchKey(
            "MODSEQ 5",
            expected: .success(.modificationSequence(.init(extensions: [:], sequenceValue: 5)))
        ),
        ParseFixture.searchKey("EMAILID 123-456-789", expected: .success(.emailID(.init("123-456-789")!))),
        ParseFixture.searchKey("THREADID 123-456-789", expected: .success(.threadID(.init("123-456-789")!))),
    ])
    func parse(_ fixture: ParseFixture<SearchKey>) {
        fixture.checkParsing()
    }

    @Test(
        arguments: [
            (SearchKey.not(.bcc("test")), true),
            (SearchKey.not(.all), false),
            (SearchKey.or(.bcc("x"), .all), true),
            (SearchKey.or(.all, .deleted), false),
            (SearchKey.and([.bcc("x"), .deleted]), true),
            (SearchKey.and([.all, .deleted]), false),
        ] as [(SearchKey, Bool)]
    )
    func usesString(_ fixture: (SearchKey, Bool)) {
        #expect(fixture.0.usesString == fixture.1)
    }

    @Test("debug description") func debugDescription() {
        #expect(SearchKey.all.debugDescription == "ALL")
        #expect(SearchKey.not(.messageSizeLarger(444)).debugDescription == "NOT LARGER 444")
    }
}

// MARK: -

extension EncodeFixture<SearchKey> {
    fileprivate static func searchKey(_ input: SearchKey, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeSearchKey($1) }
        )
    }
}

extension ParseFixture<SearchKey> {
    fileprivate static func searchKey(
        _ input: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: "\r",
            expected: expected,
            parser: GrammarParser().parseSearchKey
        )
    }
}
