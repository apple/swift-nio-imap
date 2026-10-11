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

@Suite("CharacterSetName")
struct CharacterSetNameTests {
    /// A name is written as an atom or quoted string, so ``CharacterSetName/init(_:)`` is the
    /// only thing between a caller that builds names from untrusted input and an injected command.
    @Test(
        "invalid names are rejected",
        arguments: [
            "",
            "a\rb",
            "a\nb",
            "a\u{0}b",
            "UTF-8 ÄÖÜ",  // `TEXT-CHAR` is 7-bit.
            "UTF-8 ALL\r\nA2 DELETE INBOX\r\nA3 SEARCH",  // Would inject a whole command.
            "a)] x\r\n* BYE",  // Would inject an untagged response.
        ]
    )
    func invalidNames(_ string: String) {
        #expect(CharacterSetName(string) == nil)
    }

    @Test("valid names", arguments: validNameStrings)
    func validNames(_ string: String) {
        #expect(CharacterSetName(string).map { String($0) } == string)
    }

    @Test(
        "encode",
        arguments: [
            ("UTF-8", "UTF-8"),
            ("US-ASCII", "US-ASCII"),
            ("a b", #""a b""#),
            (#"a"b\c"#, #""a\"b\\c""#),
            ("a)b", #""a)b""#),
            // `charset` has no literal form, so these stay quoted.
            ("a\tb", "\"a\tb\""),
            (String(repeating: "a ", count: 50), "\"" + String(repeating: "a ", count: 50) + "\""),
        ]
    )
    func encode(_ name: String, _ expected: String) throws {
        EncodeFixture(
            input: try #require(CharacterSetName(name)),
            bufferKind: .defaultServer,
            expectedString: expected,
            encoder: { $0.writeCharacterSetName($1) }
        ).checkEncoding()
    }

    /// Every name we accept has to parse back unchanged.
    @Test("valid names round-trip in SORT", arguments: validNameStrings)
    func sortRoundTrip(_ string: String) throws {
        let charset = try #require(CharacterSetName(string))
        expectCommandRoundTrip(.sort(criteria: [.arrival], charset: charset, key: .all))
    }

    @Test("valid names round-trip in SEARCH", arguments: validNameStrings)
    func searchRoundTrip(_ string: String) throws {
        let charset = try #require(CharacterSetName(string))
        expectCommandRoundTrip(.search(key: .subject("x"), charset: charset))
    }

    @Test("valid names round-trip in ESEARCH", arguments: validNameStrings)
    func extendedSearchRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            ExtendedSearchOptions(key: .subject("x"), charset: try #require(CharacterSetName(string))),
            terminator: "\r",
            encoder: { $0.writeExtendedSearchOptions($1) },
            parser: GrammarParser().parseExtendedSearchOptions
        )
    }

    @Test("valid names round-trip in BADCHARSET", arguments: validNameStrings)
    func badCharsetRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            ResponseTextCode.badCharset([try #require(CharacterSetName(string)), "UTF-8"]),
            terminator: "]",
            encoder: { $0.writeResponseTextCode($1) },
            parser: GrammarParser().parseResponseTextCode
        )
    }

    /// `parseQuoted` accepts bytes `charset` can't carry; those must not become a name.
    @Test("parsing rejects quoted names that can't be written back", arguments: [#""""#, "\"a\nb\"", "\"Ä\""])
    func parseRejectsInvalidQuoted(_ input: String) {
        ParseFixture(
            input: input,
            terminator: " ",
            expected: .failure,
            parser: GrammarParser().parseCharset
        ).checkParsing()
    }

    /// RFC 2978 §2.3: charset names are case-insensitive. The stored case is kept for the wire.
    @Test("compares case-insensitively, keeps case")
    func caseInsensitive() {
        let lower: CharacterSetName = "utf-8"
        let upper: CharacterSetName = "UTF-8"
        #expect(lower == upper)
        #expect(lower.hashValue == upper.hashValue)
        #expect(Set([lower, upper]).count == 1)
        #expect([lower: 1][upper] == 1)
        #expect(lower != "UTF-16")
        #expect(String(lower) == "utf-8")
    }

    /// `==` ignores case, so round-trip tests can't catch a parser that changes it.
    @Test("parsing keeps case", arguments: [("utf-8", "utf-8"), (#""utf-8 x""#, "utf-8 x")])
    func parseKeepsCase(_ input: String, _ expected: String) throws {
        var buffer = ParseBuffer(ByteBuffer(string: input + " "))
        let parsed = try GrammarParser().parseCharset(buffer: &buffer, tracker: .testTracker)
        #expect(String(parsed) == expected)
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let name: CharacterSetName = "a\r\nb"
                _ = name
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid character set name")
    }
    #endif
}

// MARK: -

private let validNameStrings = [
    "UTF-8",
    "us-ascii",
    "a b",
    #"a"b\c"#,
    "a)]b",
]

/// Encodes `command` (client mode), parses the bytes back, and expects the original command.
private func expectCommandRoundTrip(_ command: Command, sourceLocation: SourceLocation = #_sourceLocation) {
    var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: CommandEncodingOptions(), loggingMode: false)
    _ = encodeBuffer.writeCommand(command)
    var encoded = ByteBuffer()
    var remaining = encodeBuffer.buffer
    while true {
        let chunk = remaining.nextChunk()
        var bytes = chunk.bytes
        encoded.writeBuffer(&bytes)
        if !chunk.waitForContinuation { break }
    }
    encoded.writeString("\r")
    let encodedString = String(buffer: encoded)
    var parseBuffer = ParseBuffer(encoded)
    do {
        let parsed = try GrammarParser().parseCommand(buffer: &parseBuffer, tracker: .testTracker)
        #expect(parsed == command, "Encoded as \(String(reflecting: encodedString))", sourceLocation: sourceLocation)
        #expect(
            parseBuffer.readableBytes == 1,
            "Trailing bytes in \(String(reflecting: encodedString))",
            sourceLocation: sourceLocation
        )
    } catch {
        Issue.record("Failed to parse \(String(reflecting: encodedString)): \(error)", sourceLocation: sourceLocation)
    }
}
