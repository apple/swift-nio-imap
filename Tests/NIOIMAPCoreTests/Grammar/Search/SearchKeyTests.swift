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
        EncodeFixture.searchKey(.uid(.set(MessageIdentifierSetNonEmpty(set: MessageIdentifierSet<UID>(333...444))!)), "UID 333:444"),
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
        EncodeFixture.searchKey(.not(.and([.messageSizeSmaller(444), .messageSizeLarger(333)])), "NOT (SMALLER 444 LARGER 333)"),
        EncodeFixture.searchKey(.or(.not(.messageSizeSmaller(444)), .messageSizeLarger(333)), "OR (NOT SMALLER 444) LARGER 333"),
        EncodeFixture.searchKey(.or(.not(.and([.messageSizeSmaller(444), .messageSizeLarger(333)])), .undeleted), "OR (NOT (SMALLER 444 LARGER 333)) UNDELETED"),
        EncodeFixture.searchKey(.and([.or(.messageSizeSmaller(444), .messageSizeLarger(333)), .undeleted]), "(OR SMALLER 444 LARGER 333) UNDELETED"),
        EncodeFixture.searchKey(.emailID(.init("123-456-789")!), "EMAILID 123-456-789"),
        EncodeFixture.searchKey(.threadID(.init("123-456-789")!), "THREADID 123-456-789"),
    ])
    func encode(_ fixture: EncodeFixture<SearchKey>) {
        fixture.checkEncoding()
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
