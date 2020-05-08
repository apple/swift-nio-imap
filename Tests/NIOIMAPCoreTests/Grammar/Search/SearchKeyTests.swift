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
            (.before(Date(day: 25, month: .jun, year: 1994)), "BEFORE 25-jun-1994", #line),
            (.body("some body"), "BODY \"some body\"", #line),
            (.cc("tim@apple.com"), "CC \"tim@apple.com\"", #line),
            (.from("tim@apple.com"), "FROM \"tim@apple.com\"", #line),
            (.keyword(Flag.Keyword("somekeyword")), "KEYWORD SOMEKEYWORD", #line),
            (.on(Date(day: 16, month: .sep, year: 1999)), "ON 16-sep-1999", #line),
            (.since(Date(day: 17, month: .jan, year: 1984)), "SINCE 17-jan-1984", #line),
            (.subject("some subject"), "SUBJECT \"some subject\"", #line),
            (.text("some text"), "TEXT \"some text\"", #line),
            (.to("theboss@apple.com"), "TO \"theboss@apple.com\"", #line),
            (.unkeyword(Flag.Keyword("nokeyword")), "UNKEYWORD NOKEYWORD", #line),
            (.header("header", "value"), "HEADER header \"value\"", #line),
            (.larger(333), "LARGER 333", #line),
            (.not(.larger(444)), "NOT LARGER 444", #line),
            (.or(.smaller(444), .larger(666)), "OR SMALLER 444 LARGER 666", #line),
            (.sent(.on(Date(day: 7, month: .dec, year: 2018))), "SENTON 7-dec-2018", #line),
            (.smaller(555), "SMALLER 555", #line),
            (.uid([333 ... 444]), "UID 333:444", #line),
            (.sequenceSet([...222]), "222:*", #line),
            (.array([]), "()", #line),
            (.array([.smaller(444), .larger(333)]), "(SMALLER 444 LARGER 333)", #line),
            (.filter("name"), "FILTER name", #line),
        ]

        for (test, expectedString, line) in inputs {
            self.testBuffer.clear()
            let size = self.testBuffer.writeSearchKey(test)
            XCTAssertEqual(size, expectedString.utf8.count, line: line)
            XCTAssertEqual(self.testBufferString, expectedString, line: line)
        }
    }
}
