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

@Suite("FlagKeyword")
struct FlagKeywordTests {
    @Test("keyword equality")
    func keywordEquality() {
        #expect(Flag.Keyword("flag") == Flag.Keyword("flag"))
        #expect(Flag.Keyword("flagA") != Flag.Keyword("flag"))
        #expect(Flag.Keyword("flag") != Flag.Keyword("flagB"))
        #expect(Flag.Keyword("a") == Flag.Keyword("a"))
        #expect(Flag.Keyword("a") != Flag.Keyword("b"))
    }

    @Test("debug description")
    func debugDescription() {
        #expect(Flag.Keyword.forwarded.debugDescription == "$Forwarded")
        #expect(Flag.Keyword.junk.debugDescription == "$Junk")
    }

    @Test(arguments: [
        EncodeFixture.flagKeyword(
            .forwarded,
            "$Forwarded"
        ),
        EncodeFixture.flagKeyword(
            .mdnSent,
            "$MDNSent"
        ),
        EncodeFixture.flagKeyword(
            .colorBit0,
            "$MailFlagBit0"
        ),
        EncodeFixture.flagKeyword(
            .colorBit1,
            "$MailFlagBit1"
        ),
        EncodeFixture.flagKeyword(
            .colorBit2,
            "$MailFlagBit2"
        ),
        EncodeFixture.flagKeyword(
            .junk,
            "$Junk"
        ),
        EncodeFixture.flagKeyword(
            .notJunk,
            "$NotJunk"
        ),
        EncodeFixture.flagKeyword(
            .unregistered_junk,
            "Junk"
        ),
        EncodeFixture.flagKeyword(
            .unregistered_notJunk,
            "NotJunk"
        ),
        EncodeFixture.flagKeyword(
            .unregistered_forwarded,
            "Forwarded"
        ),
        EncodeFixture.flagKeyword(
            .unregistered_redirected,
            "Redirected"
        ),
    ])
    func encode(_ fixture: EncodeFixture<Flag.Keyword>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.flagKeyword("keyword", expected: .success(Flag.Keyword("keyword")!))
    ])
    func parse(_ fixture: ParseFixture<Flag.Keyword>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<Flag.Keyword> {
    fileprivate static func flagKeyword(
        _ input: Flag.Keyword,
        _ expectedString: String
    ) -> Self {
        .init(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFlagKeyword($1) }
        )
    }
}

extension ParseFixture<Flag.Keyword> {
    fileprivate static func flagKeyword(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFlagKeyword
        )
    }
}
