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

class SearchKeyTests: EncodeTestClass {}

// MARK: - IMAP

extension SearchKeyTests {
    func testEncode() {
        let inputs: [(SearchKey, String, UInt)] = [
            (.all, "ALL", #line),
            (.answered, "ANSWERED", #line),
            (.deleted, "DELETED", #line),
            (.flagged, "FLAGGED", #line),
            (.new, "NEW", #line),
            (.old, "OLD", #line),
            (.recent, "RECENT", #line),
            (.seen, "SEEN", #line),
            (.unanswered, "UNANSWERED", #line),
            (.undeleted, "UNDELETED", #line),
            (.unflagged, "UNFLAGGED", #line),
            (.unseen, "UNSEEN", #line),
            (.draft, "DRAFT", #line),
            (.undraft, "UNDRAFT", #line),
            (.bcc("hello@hello.co.uk"), "BCC \"hello@hello.co.uk\"", #line),
            (.before(Date(year: 1994, month: 6, day: 25)!), "BEFORE 25-Jun-1994", #line),
            (.body("some body"), "BODY \"some body\"", #line),
            (.cc("tim@apple.com"), "CC \"tim@apple.com\"", #line),
            (.from("tim@apple.com"), "FROM \"tim@apple.com\"", #line),
            (.keyword(Flag.Keyword("somekeyword")), "KEYWORD somekeyword", #line),
            (.on(Date(year: 1999, month: 9, day: 16)!), "ON 16-Sep-1999", #line),
            (.since(Date(year: 1984, month: 1, day: 17)!), "SINCE 17-Jan-1984", #line),
            (.subject("some subject"), "SUBJECT \"some subject\"", #line),
            (.text("some text"), "TEXT \"some text\"", #line),
            (.to("theboss@apple.com"), "TO \"theboss@apple.com\"", #line),
            (.unkeyword(Flag.Keyword("nokeyword")), "UNKEYWORD nokeyword", #line),
            (.header("header", "value"), "HEADER \"header\" \"value\"", #line),
            (.messageSizeLarger(333), "LARGER 333", #line),
            (.not(.messageSizeLarger(444)), "NOT LARGER 444", #line),
            (.or(.messageSizeSmaller(444), .messageSizeLarger(666)), "OR SMALLER 444 LARGER 666", #line),
            (.sentOn(Date(year: 2018, month: 12, day: 7)!), "SENTON 7-Dec-2018", #line),
            (.sentBefore(Date(year: 2018, month: 12, day: 7)!), "SENTBEFORE 7-Dec-2018", #line),
            (.sentSince(Date(year: 2018, month: 12, day: 7)!), "SENTSINCE 7-Dec-2018", #line),
            (.messageSizeSmaller(555), "SMALLER 555", #line),
            (.uid(UIDSet(333 ... 444)), "UID 333:444", #line),
            (.sequenceNumbers(SequenceSet(...222)), "1:222", #line),
            (.sequenceNumbers(SequenceSet(222...)), "222:*", #line),
            (.and([]), "()", #line),
            (.and([.messageSizeSmaller(444), .messageSizeLarger(333)]), "SMALLER 444 LARGER 333", #line),
            (.filter("name"), "FILTER name", #line),
            (.modificationSequence(.init(extensions: [], sequenceValue: 5)), "MODSEQ 5", #line),

            (.and([.messageSizeSmaller(444)]), "SMALLER 444", #line),
            (.not(.and([.messageSizeSmaller(444)])), "NOT SMALLER 444", #line),
            (.not(.and([.messageSizeSmaller(444), .messageSizeLarger(333)])), "NOT (SMALLER 444 LARGER 333)", #line),
            (.or(.not(.messageSizeSmaller(444)), .messageSizeLarger(333)), "OR (NOT SMALLER 444) LARGER 333", #line),
            (.or(.not(.and([.messageSizeSmaller(444), .messageSizeLarger(333)])), .undeleted), "OR (NOT (SMALLER 444 LARGER 333)) UNDELETED", #line),
            (.and([.or(.messageSizeSmaller(444), .messageSizeLarger(333)), .undeleted]), "(OR SMALLER 444 LARGER 333) UNDELETED", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchKey(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
