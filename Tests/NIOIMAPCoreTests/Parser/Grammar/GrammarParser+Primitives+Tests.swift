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

@Suite("GrammarParser Primitives")
private struct GrammarParserPrimitivesTests {
    @Test(
        "parse atom",
        arguments: [
            ParseFixture.atom("test", "\r", expected: .success("test")),
            ParseFixture.atom("hello", " ", expected: .success("hello")),
            ParseFixture.atom("hello", "", expected: .incompleteMessageIgnoringBufferModifications),
            ParseFixture.atom(" ", "", expected: .failureIgnoringBufferModifications),
        ]
    )
    func parseAtom(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test(
        "parse charset",
        arguments: [
            ParseFixture.charset("UTF8", " ", expected: .success("UTF8")),
            ParseFixture.charset("\"UTF8\"", " ", expected: .success("UTF8")),
        ]
    )
    func parseCharset(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test(
        "parse nil",
        arguments: [
            ParseFixture.nil("NIL", expected: .success(Dummy())),
            ParseFixture.nil("nil", expected: .success(Dummy())),
            ParseFixture.nil("NiL", expected: .success(Dummy())),
            ParseFixture.nil("NIT", " ", expected: .failure),
            ParseFixture.nil("\"NIL\"", " ", expected: .failure),
            ParseFixture.nil("", "", expected: .incompleteMessage),
            ParseFixture.nil("N", "", expected: .incompleteMessage),
            ParseFixture.nil("NI", "", expected: .incompleteMessage),
        ]
    )
    func parseNil(_ fixture: ParseFixture<Dummy>) {
        fixture.checkParsing()
    }

    @Test(
        "parse newline",
        arguments: [
            ParseFixture.newline("\n", expected: .success(Dummy())),
            ParseFixture.newline("\r", expected: .success(Dummy())),
            ParseFixture.newline("\r\n", expected: .success(Dummy())),
            ParseFixture.newline("\\", " ", expected: .failure),
            ParseFixture.newline("", "", expected: .incompleteMessage),
        ]
    )
    func parseNewline(_ fixture: ParseFixture<Dummy>) {
        fixture.checkParsing()
    }

    @Test(
        "parse astring",
        arguments: [
            ParseFixture.astring("NIL", " ", expected: .success("NIL")),
            ParseFixture.astring("A", " ", expected: .success("A")),
            ParseFixture.astring("Foo", " ", expected: .success("Foo")),
            ParseFixture.astring("a]b", " ", expected: .success("a]b")),
            ParseFixture.astring("{3}\r\nabc", "", expected: .success("abc")),
            ParseFixture.astring("{3+}\r\nabc", "", expected: .success("abc")),
            ParseFixture.astring(#""abc""#, "", expected: .success("abc")),
            ParseFixture.astring(#""a\\bc""#, "", expected: .success(#"a\bc"#)),
            ParseFixture.astring(#""a\"bc""#, "", expected: .success(#"a"bc"#)),
            ParseFixture.astring(#""København""#, " ", expected: .success("København")),
            ParseFixture.astring(#""a\bc""#, "", expected: .failure),
            ParseFixture.astring("\"", "", expected: .incompleteMessage),
            ParseFixture.astring(#""a\""#, "", expected: .incompleteMessage),
            ParseFixture.astring("{1}\r\n", "", expected: .incompleteMessage),
        ]
    )
    func parseAstring(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test(
        "parse nstring",
        arguments: [
            ParseFixture.nstring("NIL", "", expected: .success(nil)),
            ParseFixture.nstring("{3}\r\nabc", "", expected: .success("abc")),
            ParseFixture.nstring("{3+}\r\nabc", "", expected: .success("abc")),
            ParseFixture.nstring(#""abc""#, "", expected: .success("abc")),
            ParseFixture.nstring(#""a\\bc""#, "", expected: .success(#"a\bc"#)),
            ParseFixture.nstring(#""a\"bc""#, "", expected: .success(#"a"bc"#)),
            ParseFixture.nstring(#""København""#, "", expected: .success("København")),
            ParseFixture.nstring("abc", " ", expected: .failure),
            ParseFixture.nstring(#""a\bc""#, "", expected: .failure),
            ParseFixture.nstring("\"", "", expected: .incompleteMessage),
            ParseFixture.nstring("NI", "", expected: .incompleteMessage),
            ParseFixture.nstring("{1}\r\n", "", expected: .incompleteMessage),
        ]
    )
    func parseNstring(_ fixture: ParseFixture<String?>) {
        fixture.checkParsing()
    }

    @Test(
        "parse number",
        arguments: [
            ParseFixture.number("1234", " ", expected: .success(1234)),
            ParseFixture.number("10", " ", expected: .success(10)),
            ParseFixture.number("0", " ", expected: .success(0)),
            ParseFixture.number("abcd", " ", expected: .failure),
            ParseFixture.number("1234", "", expected: .incompleteMessage),
        ]
    )
    func parseNumber(_ fixture: ParseFixture<Int>) {
        fixture.checkParsing()
    }

    @Test(
        "parse nz-number",
        arguments: [
            ParseFixture.nzNumber("1234", " ", expected: .success(1234)),
            ParseFixture.nzNumber("10", " ", expected: .success(10)),
            ParseFixture.nzNumber("0123", " ", expected: .failure),
            ParseFixture.nzNumber("0000", " ", expected: .failure),
            ParseFixture.nzNumber("abcd", " ", expected: .failure),
            ParseFixture.nzNumber("1234", "", expected: .incompleteMessage),
        ]
    )
    func parseNzNumber(_ fixture: ParseFixture<Int>) {
        fixture.checkParsing()
    }

    static var validTextChars: [UInt8] {
        Set(UInt8.min...127)
            .subtracting([
                UInt8(ascii: "\r"),
                UInt8(ascii: "\n"),
                0,
            ])
            .sorted()
    }

    @Test(
        "parse text",
        arguments: [
            ParseFixture.text(
                String(decoding: validTextChars, as: UTF8.self),
                "\r",
                expected: .success(String(decoding: validTextChars, as: UTF8.self))
            ),
            ParseFixture.text("\r", "", expected: .failure),
            ParseFixture.text("\n", "", expected: .failure),
            ParseFixture.text(String(decoding: (UInt8(128)...UInt8.max), as: UTF8.self), " ", expected: .failure),
            ParseFixture.text("a", "", expected: .incompleteMessage),
        ]
    )
    func parseText(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test(
        "parse uchar",
        arguments: [
            ParseFixture.uchar(
                "%00",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")])
            ),
            ParseFixture.uchar(
                "%0A",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "A")])
            ),
            ParseFixture.uchar(
                "%1F",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "1"), UInt8(ascii: "F")])
            ),
            ParseFixture.uchar(
                "%FF",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "F"), UInt8(ascii: "F")])
            ),
            // Lowercase hex digits get uppercased
            ParseFixture.uchar(
                "%1a",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "1"), UInt8(ascii: "A")])
            ),
            ParseFixture.uchar(
                "%ff",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "F"), UInt8(ascii: "F")])
            ),
            ParseFixture.uchar("%GG", " ", expected: .failure),
            ParseFixture.uchar("%", "", expected: .incompleteMessage),
        ]
    )
    func parseUchar(_ fixture: ParseFixture<[UInt8]>) {
        fixture.checkParsing()
    }

    @Test(
        "parse achar",
        arguments: [
            ParseFixture.achar(
                "%00",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")])
            ),
            ParseFixture.achar("&", "", expected: .success([UInt8(ascii: "&")])),
            ParseFixture.achar("=", "", expected: .success([UInt8(ascii: "=")])),
            ParseFixture.achar("£", " ", expected: .failure),
            ParseFixture.achar("", "", expected: .incompleteMessage),
        ]
    )
    func parseAchar(_ fixture: ParseFixture<[UInt8]>) {
        fixture.checkParsing()
    }

    @Test(
        "parse bchar",
        arguments: [
            ParseFixture.bchar(
                "%00",
                "",
                expected: .success([UInt8(ascii: "%"), UInt8(ascii: "0"), UInt8(ascii: "0")])
            ),
            ParseFixture.bchar("@", "", expected: .success([UInt8(ascii: "@")])),
            ParseFixture.bchar(":", "", expected: .success([UInt8(ascii: ":")])),
            ParseFixture.bchar("/", "", expected: .success([UInt8(ascii: "/")])),
            ParseFixture.bchar("£", " ", expected: .failure),
            ParseFixture.bchar("", "", expected: .incompleteMessage),
        ]
    )
    func parseBchar(_ fixture: ParseFixture<[UInt8]>) {
        fixture.checkParsing()
    }

    @Test(
        "parse 2DIGIT",
        arguments: [
            ParseFixture.twoDigit("12", " ", expected: .success(12)),
            ParseFixture.twoDigit("ab", " ", expected: .failure),
            ParseFixture.twoDigit("1a", " ", expected: .failure),
            ParseFixture.twoDigit("", "", expected: .incompleteMessage),
            ParseFixture.twoDigit("1", "", expected: .incompleteMessage),
        ]
    )
    func parse2Digit(_ fixture: ParseFixture<Int>) {
        fixture.checkParsing()
    }

    @Test(
        "parse 4DIGIT",
        arguments: [
            ParseFixture.fourDigit("1234", " ", expected: .success(1234)),
            ParseFixture.fourDigit("abcd", " ", expected: .failure),
            ParseFixture.fourDigit("12ab", " ", expected: .failure),
            ParseFixture.fourDigit("", "", expected: .incompleteMessage),
            ParseFixture.fourDigit("1", "", expected: .incompleteMessage),
            ParseFixture.fourDigit("12", "", expected: .incompleteMessage),
            ParseFixture.fourDigit("123", "", expected: .incompleteMessage),
        ]
    )
    func parse4Digit(_ fixture: ParseFixture<Int>) {
        fixture.checkParsing()
    }

    @Test(
        "parse tag",
        arguments: [
            ParseFixture.tag("abc", "\r", expected: .success("abc")),
            ParseFixture.tag("abc", "+", expected: .success("abc")),
            ParseFixture.tag("+", "", expected: .failure),
            ParseFixture.tag("", "", expected: .incompleteMessage),
        ]
    )
    func parseTag(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test(
        "parse vendor-token",
        arguments: [
            ParseFixture.vendorToken("token", "-atom ", expected: .success("token")),
            ParseFixture.vendorToken("token", " ", expected: .success("token")),
            ParseFixture.vendorToken("1a", " ", expected: .failure),
            ParseFixture.vendorToken("token", "", expected: .incompleteMessage),
        ]
    )
    func parseVendorToken(_ fixture: ParseFixture<String>) {
        fixture.checkParsing()
    }

    @Test("parseLiteralSize with and without tilde prefix")
    func parseLiteralSizeVariants() throws {
        let parser = GrammarParser()

        // Standard {N}\r\n — single-arg overload (covers lines 1467-1468)
        var b1 = ParseBuffer("{5}\r\n")
        let size1 = try parser.parseLiteralSize(buffer: &b1, tracker: .makeNewDefault)
        #expect(size1 == 5)

        // Binary ~{N}\r\n — covers the ~ optional branch in the two-arg overload (line 1474)
        var b2 = ParseBuffer("~{5}\r\n")
        let size2 = try parser.parseLiteralSize(buffer: &b2, tracker: .makeNewDefault)
        #expect(size2 == 5)
    }

    @Test("parseLiteral with NUL byte throws")
    func parseLiteralNULByte() {
        let parser = GrammarParser()
        // Literal containing a NUL byte (0x00) — covers line 1495
        var b = ParseBuffer("{3}\r\na\0b")
        #expect(throws: (any Error).self) {
            try parser.parseLiteral(buffer: &b, tracker: .makeNewDefault)
        }
    }

    @Test("parseLiteral8 non-synchronizing literal and NUL byte")
    func parseLiteral8Variants() throws {
        let parser = GrammarParser()

        // Non-synchronizing ~{N+}\r\n — covers the + optional branch (line 1508)
        var b1 = ParseBuffer("~{3+}\r\nabc")
        let result = try parser.parseLiteral8(buffer: &b1, tracker: .makeNewDefault)
        #expect(String(buffer: result) == "abc")

        // Literal8 containing a NUL byte — covers line 1513
        var b2 = ParseBuffer("~{3}\r\na\0b")
        #expect(throws: (any Error).self) {
            try parser.parseLiteral8(buffer: &b2, tracker: .makeNewDefault)
        }
    }
}

// MARK: -

extension ParseFixture<String> {
    fileprivate static func atom(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAtom
        )
    }

    fileprivate static func charset(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseCharset
        )
    }

    fileprivate static func text(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                let buffer = try GrammarParser().parseText(buffer: &$0, tracker: $1)
                return String(buffer: buffer)
            }
        )
    }

    fileprivate static func astring(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                let buffer = try GrammarParser().parseAString(buffer: &$0, tracker: $1)
                return String(buffer: buffer)
            }
        )
    }

    fileprivate static func tag(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseTag
        )
    }

    fileprivate static func vendorToken(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseVendorToken
        )
    }
}

extension ParseFixture<String?> {
    fileprivate static func nstring(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                let buffer = try GrammarParser().parseNString(buffer: &$0, tracker: $1)
                return buffer.map { String(buffer: $0) }
            }
        )
    }
}

/// `Void` / `nil` replacement that is `Equatable`.
private struct Dummy: Equatable {}

extension ParseFixture<Dummy> {
    fileprivate static func `nil`(
        _ input: String,
        _ terminator: String = "",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                try GrammarParser().parseNil(buffer: &$0, tracker: $1)
                return Dummy()
            }
        )
    }

    fileprivate static func newline(
        _ input: String,
        _ terminator: String = "",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: {
                try PL.parseNewline(buffer: &$0, tracker: $1)
                return Dummy()
            }
        )
    }
}

extension ParseFixture<Int> {
    fileprivate static func number(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseNumber
        )
    }

    fileprivate static func nzNumber(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseNZNumber
        )
    }

    fileprivate static func twoDigit(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parse2Digit
        )
    }

    fileprivate static func fourDigit(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parse4Digit
        )
    }
}

extension ParseFixture<[UInt8]> {
    fileprivate static func uchar(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseUChar
        )
    }

    fileprivate static func achar(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseAChar
        )
    }

    fileprivate static func bchar(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseBChar
        )
    }
}
