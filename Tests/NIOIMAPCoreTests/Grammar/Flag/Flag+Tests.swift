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

@Suite("Flag")
struct FlagTests {
    @Test("keyword initialization")
    func keywordInitialization() {
        #expect(Flag.Keyword("Redirected").map { String($0) } == "Redirected")
        #expect(Flag.Keyword("redirected").map { String($0) } == "redirected")
        #expect(Flag.Keyword("$MailFlagBit0").map { String($0) } == "$MailFlagBit0")
        #expect(Flag.Keyword("OIB-Seen-[Gmail]/Trash").map { String($0) } == "OIB-Seen-[Gmail]/Trash")

        #expect(Flag.Keyword(#"a"b"#) == nil)
        #expect(Flag.Keyword(#"a(b"#) == nil)
        #expect(Flag.Keyword(#"a)b"#) == nil)
        #expect(Flag.Keyword(#"a{b"#) == nil)
        #expect(Flag.Keyword(#"a b"#) == nil)
        #expect(Flag.Keyword(#"a%b"#) == nil)
        #expect(Flag.Keyword(#"a*b"#) == nil)
    }

    @Test(
        "extension initialization",
        arguments: [
            (Flag.extension("\\ANSWERED"), Flag.answered),
            (Flag.extension("\\answered"), Flag.answered),
            (Flag.extension("\\deleted"), Flag.deleted),
            (Flag.extension("\\seen"), Flag.seen),
            (Flag.extension("\\draft"), Flag.draft),
            (Flag.extension("\\flagged"), Flag.flagged),
        ]
    )
    func extensionInitialization(_ input: Flag, _ expected: Flag) {
        #expect(input == expected)
    }

    @Test("equality checks")
    func equalityChecks() {
        expectEqualAndEqualHash(Flag.answered, .answered)
        expectEqualAndEqualHash(Flag.flagged, .flagged)
        expectEqualAndEqualHash(Flag.deleted, .deleted)
        expectEqualAndEqualHash(Flag.seen, .seen)
        expectEqualAndEqualHash(Flag.draft, .draft)
        expectEqualAndEqualHash(Flag.keyword(.colorBit0), .keyword(.colorBit0))
        expectEqualAndEqualHash(Flag.keyword(.junk), .keyword(.junk))
        expectEqualAndEqualHash(Flag.keyword(.unregistered_junk), .keyword(.unregistered_junk))
        expectEqualAndEqualHash(Flag.keyword(Flag.Keyword("FooBar")!), .keyword(Flag.Keyword("FooBar")!))
        expectEqualAndEqualHash(Flag.extension("\\FooBar"), .extension("\\FooBar"))
        expectEqualAndEqualHash(Flag.answered, .extension("\\Answered"))

        // Case-insensitive:
        expectEqualAndEqualHash(Flag.answered, .extension("\\ANSWERED"))
        expectEqualAndEqualHash(Flag.answered, .extension("\\answered"))
        expectEqualAndEqualHash(Flag.keyword(Flag.Keyword("foobar")!), .keyword(Flag.Keyword("FOOBAR")!))
        expectEqualAndEqualHash(Flag.keyword(Flag.Keyword("FOOBAR")!), .keyword(Flag.Keyword("foobar")!))
        expectEqualAndEqualHash(Flag.keyword(Flag.Keyword("FOOBAR")!), .keyword(Flag.Keyword("FooBar")!))
        expectEqualAndEqualHash(Flag.extension("\\foobar"), .extension("\\FOOBAR"))
        expectEqualAndEqualHash(Flag.extension("\\FOOBAR"), .extension("\\foobar"))
        expectEqualAndEqualHash(Flag.extension("\\FOOBAR"), .extension("\\FooBar"))
    }

    @Test("inequality checks")
    func inequalityChecks() {
        #expect(Flag.answered != .flagged)
        #expect(Flag.answered != .deleted)
        #expect(Flag.answered != .seen)
        #expect(Flag.answered != .draft)
        #expect(Flag.answered != .keyword(.colorBit0))
        #expect(Flag.answered != .keyword(.junk))
        #expect(Flag.answered != .keyword(.unregistered_junk))
        #expect(Flag.answered != .keyword(Flag.Keyword("FooBar")!))
        #expect(Flag.answered != .extension("\\FooBar"))

        #expect(Flag.extension("\\Baz") != .answered)
        #expect(Flag.extension("\\Baz") != .flagged)
        #expect(Flag.extension("\\Baz") != .deleted)
        #expect(Flag.extension("\\Baz") != .seen)
        #expect(Flag.extension("\\Baz") != .draft)
        #expect(Flag.extension("\\Baz") != .keyword(.colorBit0))
        #expect(Flag.extension("\\Baz") != .keyword(.junk))
        #expect(Flag.extension("\\Baz") != .keyword(.unregistered_junk))
        #expect(Flag.extension("\\Baz") != .keyword(Flag.Keyword("FooBar")!))
        #expect(Flag.extension("\\Baz") != .extension("\\FooBar"))
        #expect(Flag.extension("\\Baz") != .extension("\\Answered"))

        #expect(Flag.keyword(.notJunk) != .answered)
        #expect(Flag.keyword(.notJunk) != .flagged)
        #expect(Flag.keyword(.notJunk) != .deleted)
        #expect(Flag.keyword(.notJunk) != .seen)
        #expect(Flag.keyword(.notJunk) != .draft)
        #expect(Flag.keyword(.notJunk) != .keyword(.colorBit0))
        #expect(Flag.keyword(.notJunk) != .keyword(.junk))
        #expect(Flag.keyword(.notJunk) != .keyword(.unregistered_junk))
        #expect(Flag.keyword(.notJunk) != .keyword(Flag.Keyword("FooBar")!))
        #expect(Flag.keyword(.notJunk) != .extension("\\FooBar"))
        #expect(Flag.keyword(.notJunk) != .extension("\\Answered"))
    }

    @Test(arguments: [
        EncodeFixture.flag(.answered, "\\Answered"),
        EncodeFixture.flag(.deleted, "\\Deleted"),
        EncodeFixture.flag(.draft, "\\Draft"),
        EncodeFixture.flag(.flagged, "\\Flagged"),
        EncodeFixture.flag(.seen, "\\Seen"),
        EncodeFixture.flag(.keyword(.forwarded), "$Forwarded"),
        // Case insensitive, but case preserving:
        EncodeFixture.flag(.extension("\\extension"), "\\extension"),
        EncodeFixture.flag(.extension("\\Extension"), "\\Extension"),
        EncodeFixture.flag(.extension("\\EXTENSION"), "\\EXTENSION"),
        EncodeFixture.flag(.keyword(Flag.Keyword("$extension")!), "$extension"),
        EncodeFixture.flag(.keyword(Flag.Keyword("$Extension")!), "$Extension"),
        EncodeFixture.flag(.keyword(Flag.Keyword("$EXTENSION")!), "$EXTENSION"),
    ])
    func encode(_ fixture: EncodeFixture<Flag>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.flag(#"\Answered"#, expected: .success(.answered)),
        ParseFixture.flag(#"\flagged"#, expected: .success(.flagged)),
        ParseFixture.flag(#"\deleted"#, expected: .success(.deleted)),
        ParseFixture.flag(#"\seen"#, expected: .success(.seen)),
        ParseFixture.flag(#"\Draft"#, expected: .success(.draft)),
        ParseFixture.flag(#"\extension"#, expected: .success(.extension(#"\extension"#))),
        ParseFixture.flag(#"$Forwarded"#, expected: .success("$Forwarded")),
        ParseFixture.flag(#"Forwarded"#, expected: .success("Forwarded")),
        ParseFixture.flag(#"$MailFlagBit0"#, expected: .success("$MailFlagBit0")),
        ParseFixture.flag(#"$MailFlagBit2"#, expected: .success("$MailFlagBit2")),
        ParseFixture.flag(#"OIB-Seen-INBOX"#, expected: .success("OIB-Seen-INBOX")),
        ParseFixture.flag(#"OIB-Seen-Unsubscribe"#, expected: .success("OIB-Seen-Unsubscribe")),
        ParseFixture.flag(#"OIB-Seen-[Gmail]/Trash"#, expected: .success("OIB-Seen-[Gmail]/Trash")),
    ])
    func parse(_ fixture: ParseFixture<Flag>) {
        fixture.checkParsing()
    }

    @Test(
        "parse flag list",
        arguments: [
            ParseFixture.flagList("()", expected: .success([])),
            ParseFixture.flagList(#"(\seen)"#, expected: .success([.seen])),
            ParseFixture.flagList(#"(\seen \answered \draft)"#, expected: .success([.seen, .answered, .draft])),
            ParseFixture.flagList(#"(\seen \answered \draft )"#, expected: .success([.seen, .answered, .draft])),
        ]
    )
    func parseFlagList(_ fixture: ParseFixture<[Flag]>) {
        fixture.checkParsing()
    }

    @Test(
        "parse flag extension",
        arguments: [
            ParseFixture.flagExtension(#"\Something"#, expected: .success(#"\Something"#)),
            ParseFixture.flagExtension("Something ", " ", expected: .failureIgnoringBufferModifications),
        ]
    )
    func parseFlagExtension(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }
}

// MARK: -

extension EncodeFixture<Flag> {
    fileprivate static func flag(_ input: Flag, _ expectedString: String) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeFlag($1) }
        )
    }
}

extension ParseFixture<Flag> {
    fileprivate static func flag(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFlag
        )
    }
}

extension ParseFixture<[Flag]> {
    fileprivate static func flagList(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFlagList
        )
    }
}

extension ParseFixture<String> {
    fileprivate static func flagExtension(
        _ input: String,
        _ terminator: String = " ",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseFlagExtension
        )
    }
}
