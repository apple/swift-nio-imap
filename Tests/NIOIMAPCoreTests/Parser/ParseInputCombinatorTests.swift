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

@_spi(NIOIMAPInternal) @testable import NIOIMAPCore

import OrderedCollections
import Testing

/// The grammar's building blocks, as methods on the cursor.
///
/// These were tests of `ParserLibrary`'s free functions. The cursor is non-escapable, so a test cannot
/// build one and read from it across statements — every case runs inside a closure instead.
@Suite("ParseInput combinators")
struct ParseInputCombinatorTests {}

// MARK: - parseOptional

extension ParseInputCombinatorTests {
    @Test("parseOptional throws incomplete message when buffer is empty")
    func parseOptionalThrowsIncompleteMessageWhenBufferIsEmpty() {
        TestUtilities.withParseInput(for: "") { buffer in
            let error = parseErrorThrown {
                try buffer.parseOptional(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                    try buffer.matchFixed("x")
                }
            }
            #expect(error is IncompleteMessage)
        }
    }

    @Test("parseOptional succeeds when element is present")
    func parseOptionalSucceedsWhenElementIsPresent() throws {
        try TestUtilities.withParseInput(for: "x") { buffer in
            try buffer.parseOptional(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                try buffer.matchFixed("x")
            }
        }
    }

    @Test("parseOptional succeeds when element is not present")
    func parseOptionalSucceedsWhenElementIsNotPresent() throws {
        try TestUtilities.withParseInput(for: "y") { buffer in
            try buffer.parseOptional(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                try buffer.matchFixed("x")
            }
            #expect(buffer.remaining == 1)
        }
    }

    @Test("parseOptional resets buffer correctly for composite parsers with incomplete input")
    func parseOptionalResetsBufferCorrectlyForCompositeParsersWithIncompleteInput() {
        TestUtilities.withParseInput(for: "x") { buffer in
            let error = parseErrorThrown {
                try buffer.parseOptional(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                    try buffer.matchFixed("x")
                    try buffer.matchFixed("y")
                }
            }
            #expect(error is IncompleteMessage)
            #expect(buffer.remaining == 1)
        }
    }

    @Test("parseOptional resets buffer correctly for composite parsers with non-matching input")
    func parseOptionalResetsBufferCorrectlyForCompositeParsersWithNonMatchingInput() throws {
        try TestUtilities.withParseInput(for: "xz") { buffer in
            try buffer.parseOptional(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                try buffer.matchFixed("x")
                try buffer.matchFixed("y")
            }
            #expect(buffer.remaining == 2)
        }
    }
}

// MARK: - matchFixed

extension ParseInputCombinatorTests {
    @Test("matchFixed with case sensitive matching")
    func matchFixedWithCaseSensitiveMatching() throws {
        try TestUtilities.withParseInput(for: "fooFooFOO") { buffer in
            try buffer.matchFixed("fooFooFOO", caseSensitivity: .caseSensitive)
        }

        TestUtilities.withParseInput(for: "fooFooFOO") { buffer in
            #expect(
                parseErrorThrown { try buffer.matchFixed("foofoofoo", caseSensitivity: .caseSensitive) } is ParserError
            )
        }

        TestUtilities.withParseInput(for: "foo") { buffer in
            #expect(
                parseErrorThrown { try buffer.matchFixed("fooFooFOO", caseSensitivity: .caseSensitive) }
                    is IncompleteMessage
            )
        }
    }

    @Test("matchFixed with case insensitive matching")
    func matchFixedWithCaseInsensitiveMatching() throws {
        try TestUtilities.withParseInput(for: "fooFooFOO") { buffer in
            try buffer.matchFixed("fooFooFOO")
        }

        try TestUtilities.withParseInput(for: "fooFooFOO") { buffer in
            try buffer.matchFixed("foofoofoo")
        }

        TestUtilities.withParseInput(for: "foo") { buffer in
            #expect(parseErrorThrown { try buffer.matchFixed("fooFooFOO") } is IncompleteMessage)
        }
    }

    @Test("matchFixed rejects non-ASCII characters")
    func matchFixedRejectsNonAsciiCharacters() {
        TestUtilities.withParseInput(for: "fooFooFOÖ") { buffer in
            #expect(
                parseErrorThrown { try buffer.matchFixed("fooFooFOO", caseSensitivity: .caseSensitive) } is ParserError
            )
        }
    }

    @Test("matchFixed with leading spaces")
    func matchFixedWithLeadingSpaces() throws {
        try TestUtilities.withParseInput(for: String(repeating: " ", count: 500) + "fooFooFOO") { buffer in
            try buffer.matchFixed("fooFooFOO", caseSensitivity: .caseSensitive, leadingSpaces: .allowed)
        }
    }

    @Test("matchFixed with leading spaces consumes nothing when the needle does not follow")
    func matchFixedWithLeadingSpacesConsumesNothingOnMismatch() {
        TestUtilities.withParseInput(for: "   bar") { buffer in
            #expect(parseErrorThrown { try buffer.matchFixed("foo", leadingSpaces: .allowed) } is ParserError)
            #expect(buffer.remaining == 6)
        }
    }
}

// MARK: - parseZeroOrMore

extension ParseInputCombinatorTests {
    @Test("parseZeroOrMore parses nothing when no match but data present")
    func parseZeroOrMoreParsesNothingWhenNoMatchButDataPresent() throws {
        TestUtilities.withParseInput("", terminator: "xy") { buffer in
            let result = try buffer.parseZeroOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) -> Int in
                try buffer.matchFixed("x")
                try buffer.matchFixed("x")
                return 1
            }
            #expect(result == [])
        }
    }

    @Test("parseZeroOrMore throws incomplete message when no data")
    func parseZeroOrMoreThrowsIncompleteMessageWhenNoData() throws {
        TestUtilities.withParseInput("") { buffer in
            let error = parseErrorThrown {
                try buffer.parseZeroOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                    try buffer.matchFixed("x")
                    try buffer.matchFixed("x")
                }
            }
            #expect(error is IncompleteMessage)
        }
    }

    @Test("parseZeroOrMore parses one item when more data present")
    func parseZeroOrMoreParsesOneItemWhenMoreDataPresent() throws {
        TestUtilities.withParseInput("xx", terminator: "xy") { buffer in
            let result = try buffer.parseZeroOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) -> Int in
                try buffer.matchFixed("x")
                try buffer.matchFixed("x")
                return 1
            }
            #expect(result == [1])
        }
    }

    @Test("parseZeroOrMore parses two items when more data present")
    func parseZeroOrMoreParsesTwoItemsWhenMoreDataPresent() throws {
        TestUtilities.withParseInput("xxxx", terminator: "xy") { buffer in
            let result = try buffer.parseZeroOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) -> Int in
                try buffer.matchFixed("x")
                try buffer.matchFixed("x")
                return 1
            }
            #expect(result == [1, 1])
        }
    }
}

// MARK: - Forward progress

/// Matches without consuming the first `count` times, then stops matching — so with the forward-progress
/// guard removed a repetition ends after `count` results instead of hanging the test run.
private final class EmptyMatches {
    private var remaining: Int

    init(count: Int) { self.remaining = count }

    func next() throws(ParseFailure) {
        guard remaining > 0 else { throw .mismatch("done") }
        remaining -= 1
    }
}

private let emptyMatchCount = 3

extension ParseInputCombinatorTests {
    @Test("parseZeroOrMore throws when an element consumes nothing")
    func parseZeroOrMoreThrowsWithoutProgress() {
        let matches = EmptyMatches(count: emptyMatchCount)
        TestUtilities.withParseInput(for: "xy") { buffer in
            let error = parseErrorThrown {
                try buffer.parseZeroOrMore(tracker: .testTracker) { _, _ throws(ParseFailure) -> Int in
                    try matches.next()
                    return 1
                }
            }
            #expect(error is NoForwardProgress)
        }
    }

    @Test("parseOneOrMore throws when a repeated element consumes nothing")
    func parseOneOrMoreThrowsWithoutProgress() {
        let matches = EmptyMatches(count: emptyMatchCount)
        TestUtilities.withParseInput(for: "xy") { buffer in
            let error = parseErrorThrown {
                try buffer.parseOneOrMore(tracker: .testTracker) { _, _ throws(ParseFailure) -> Int in
                    try matches.next()
                    return 1
                }
            }
            #expect(error is NoForwardProgress)
        }
    }

    @Test("parseZeroOrMore into a dictionary throws when an element consumes nothing")
    func parseZeroOrMoreIntoDictionaryThrowsWithoutProgress() {
        let matches = EmptyMatches(count: emptyMatchCount)
        TestUtilities.withParseInput(for: "xy") { buffer in
            var dictionary = OrderedDictionary<Int, Int>()
            let error = parseErrorThrown {
                try buffer.parseZeroOrMore(into: &dictionary, tracker: .testTracker) {
                    _,
                    _ throws(ParseFailure) -> (Int, Int) in
                    try matches.next()
                    return (1, 1)
                }
            }
            #expect(error is NoForwardProgress)
        }
    }

    @Test("parseZeroOrMore into a dictionary of KeyValue throws when an element consumes nothing")
    func parseZeroOrMoreIntoKeyValueDictionaryThrowsWithoutProgress() {
        let matches = EmptyMatches(count: emptyMatchCount)
        TestUtilities.withParseInput(for: "xy") { buffer in
            var dictionary = OrderedDictionary<Int, Int>()
            let error = parseErrorThrown {
                try buffer.parseZeroOrMore(into: &dictionary, tracker: .testTracker) {
                    _,
                    _ throws(ParseFailure) -> KeyValue<Int, Int> in
                    try matches.next()
                    return KeyValue(key: 1, value: 1)
                }
            }
            #expect(error is NoForwardProgress)
        }
    }

    @Test("NoForwardProgress names the check that fired")
    func noForwardProgressDescription() {
        let line = #line + 1
        let error = NoForwardProgress()
        #expect(
            String(describing: error) == "NoForwardProgress at NIOIMAPCoreTests/ParseInputCombinatorTests.swift:\(line)"
        )
    }

    /// `ParserError` locations name the site that threw, not the file that declared the default argument.
    @Test("ParserError names the throwing site's file")
    func parserErrorNamesThrowingFile() {
        let thisFile = "NIOIMAPCoreTests/ParseInputCombinatorTests.swift"
        func site(_ error: (any Error)?) -> String {
            guard let error = error as? ParserError else { return "<not a ParserError>" }
            return "\(error.file):\(error.line)"
        }
        func here(_ line: Int = #line) -> String { "\(thisFile):\(line)" }
        func thrown(_ failure: ParseFailure) -> (any Error)? { failure.unwrapped }
        #expect(site(ParserError()) == here())
        #expect(site(ParserError.invalidUTF8()) == here())
        #expect(site(parseErrorThrown { try decodeUTF8([0xFF]) }) == here())
        #expect(site(thrown(.mismatch())) == here())
        #expect(site(thrown(.mismatch("literal"))) == here())
        #expect(site(thrown(.mismatch(dynamicHint: "dynamic \(1)"))) == here())
        #expect(site(ParserError(dynamicHint: "dynamic \(1)")) == here())
        TestUtilities.withParseInput(for: "xy") { buffer in
            let first = ParseAlternative<Int> { _, _ throws(ParseFailure) in throw .mismatch() }
            let second = ParseAlternative<Int> { _, _ throws(ParseFailure) in throw .mismatch() }
            let oneOf = parseErrorThrown {
                try buffer.parseOneOf([first, second], tracker: .testTracker)
            }
            #expect(site(oneOf) == here(#line - 2))
        }
    }

    @Test("ParserError hints survive the compact storage")
    func parserErrorHints() {
        func hint(_ failure: ParseFailure) -> String? {
            (failure.unwrapped as? ParserError)?.hint
        }
        #expect(hint(.mismatch()) == "Unknown")
        #expect(hint(.mismatch("Fixed string mismatch")) == "Fixed string mismatch")
        #expect(hint(.mismatch("Non-ASCII: \u{2019}")) == "Non-ASCII: \u{2019}")
        let byte = 42
        #expect(hint(.mismatch(dynamicHint: "Unexpected byte \(byte)")) == "Unexpected byte 42")

        let line = #line + 1
        var error = ParserError(hint: "before")
        error.hint = "after"
        #expect(error.hint == "after")
        #expect(error.line == line)
    }

    /// No allocation on throw for literal hints; typed throws also need it small to return it in registers.
    @Test("ParserError is 24 bytes")
    func parserErrorSize() {
        #expect(MemoryLayout<ParserError>.size == 24)
    }

    /// `ParseFailure` is thrown on every failed alternative. At most 4 words it is returned in registers;
    /// larger, it goes through a hidden out-pointer, which doubled debug-build stack use per nesting level
    /// (64 bytes: 4505 vs 2252 bytes per level). Keep payloads compact; box rare large ones.
    @Test("ParseFailure fits in registers")
    func parseFailureSize() {
        #expect(MemoryLayout<ParseFailure>.size <= 32)
    }

    /// An error from an untyped callee keeps its meaning: e.g. a `ParserError` must still backtrack.
    @Test("ParseFailure classifies every public parser error")
    func parseFailureRoundTrips() {
        struct Unrelated: Error {}
        func kind(_ failure: ParseFailure) -> String {
            switch failure {
            case .mismatch: "mismatch"
            case .badCommand: "badCommand"
            case .incomplete: "incomplete"
            case .noForwardProgress: "noForwardProgress"
            case .tooMuchRecursion: "tooMuchRecursion"
            case .literalSizeExceeded: "literalSizeExceeded"
            case .messageAttributesExceeded: "messageAttributesExceeded"
            case .bodySizeExceeded: "bodySizeExceeded"
            case .other: "other"
            }
        }
        let failures: [ParseFailure] = [
            .mismatch(),
            .badCommand(BadCommand(commandTag: "A1", parserError: ParserError())),
            .incomplete,
            .noForwardProgress(NoForwardProgress()),
            .tooMuchRecursion(TooMuchRecursion(limit: 1)),
            .literalSizeExceeded(ExceededLiteralSizeLimitError(actualCount: 2, maximumCount: 1)),
            .messageAttributesExceeded(ExceededMaximumMessageAttributesError(actualCount: 2, maximumCount: 1)),
            .bodySizeExceeded(ExceededMaximumBodySizeError(actualCount: 2, maximumCount: 1)),
            .other(Unrelated()),
        ]
        for failure in failures {
            #expect(kind(ParseFailure(failure.unwrapped)) == kind(failure))
        }
    }

    /// `NoForwardProgress` is not a "did not match": the backtracking combinators must let it through.
    @Test("parseOptional and parseOneOf do not absorb NoForwardProgress")
    func backtrackingDoesNotAbsorbNoForwardProgress() {
        TestUtilities.withParseInput(for: "xy") { buffer in
            let optional = parseErrorThrown {
                try buffer.parseOptional(tracker: .testTracker) { _, _ throws(ParseFailure) -> Int in
                    throw .noForwardProgress(NoForwardProgress())
                }
            }
            #expect(optional is NoForwardProgress)
            let stuck = ParseAlternative<Int> { _, _ throws(ParseFailure) in
                throw .noForwardProgress(NoForwardProgress())
            }
            let succeeds = ParseAlternative<Int> { _, _ throws(ParseFailure) in 1 }
            let oneOf = parseErrorThrown {
                try buffer.parseOneOf([stuck, succeeds], tracker: .testTracker)
            }
            #expect(oneOf is NoForwardProgress)
        }
    }
}

// MARK: - Incomplete is not a mismatch

extension ParseInputCombinatorTests {
    /// Hand-written list loops used to end on *any* error, so a list cut short by the end of the input
    /// came back as complete. Only a `ParserError` ends one now.
    @Test("a mailbox flag list cut short by the end of the input is incomplete")
    func mailboxListFlagsIncomplete() {
        TestUtilities.withParseInput(for: #"\Noselect \Mar"#) { buffer in
            let error = parseErrorThrown {
                try GrammarParser().parseMailboxListFlags(buffer: &buffer, tracker: .testTracker)
            }
            #expect(error is IncompleteMessage)
        }
    }

    @Test("a tagged extension continuation cut short by the end of the input is incomplete")
    func taggedExtensionContinuationIncomplete() {
        TestUtilities.withParseInput(for: " foo ba") { buffer in
            var parts: [String] = []
            let error = parseErrorThrown {
                try GrammarParser().parseTaggedExtensionComplex_continuation(
                    into: &parts,
                    buffer: &buffer,
                    tracker: .testTracker
                )
            }
            #expect(error is IncompleteMessage)
        }
    }
}

// MARK: - parseOneOrMore

extension ParseInputCombinatorTests {
    @Test("parseOneOrMore throws parser error when no match but data present")
    func parseOneOrMoreThrowsParserErrorWhenNoMatchButDataPresent() throws {
        TestUtilities.withParseInput("", terminator: "xy") { buffer in
            let error = parseErrorThrown {
                try buffer.parseOneOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                    try buffer.matchFixed("x")
                    try buffer.matchFixed("x")
                }
            }
            #expect(error is ParserError)
        }
    }

    @Test("parseOneOrMore throws incomplete message when no data")
    func parseOneOrMoreThrowsIncompleteMessageWhenNoData() throws {
        TestUtilities.withParseInput("") { buffer in
            let error = parseErrorThrown {
                try buffer.parseOneOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) in
                    try buffer.matchFixed("x")
                    try buffer.matchFixed("x")
                }
            }
            #expect(error is IncompleteMessage)
        }
    }

    @Test("parseOneOrMore parses one item when more data present")
    func parseOneOrMoreParsesOneItemWhenMoreDataPresent() throws {
        TestUtilities.withParseInput("xx", terminator: "xy") { buffer in
            let result = try buffer.parseOneOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) -> Int in
                try buffer.matchFixed("x")
                try buffer.matchFixed("x")
                return 1
            }
            #expect(result == [1])
        }
    }

    @Test("parseOneOrMore parses two items when more data present")
    func parseOneOrMoreParsesTwoItemsWhenMoreDataPresent() throws {
        TestUtilities.withParseInput("xxxx", terminator: "xy") { buffer in
            let result = try buffer.parseOneOrMore(tracker: .testTracker) { buffer, _ throws(ParseFailure) -> Int in
                try buffer.matchFixed("x")
                try buffer.matchFixed("x")
                return 1
            }
            #expect(result == [1, 1])
        }
    }
}

// MARK: - parseSpaces

extension ParseInputCombinatorTests {
    @Test(
        "parseSpaces consumes leading spaces",
        arguments: [
            (" a", "a"),
            ("       a", "a"),
            ("  a  ", "a  "),
        ]
    )
    func parseSpacesConsumesLeadingSpaces(input: String, expectedRemaining: String) throws {
        try TestUtilities.withParseInput(for: input) { buffer in
            try buffer.parseSpaces()
            let rest = try buffer.extractBytes(length: buffer.remaining)
            #expect(String(decoding: rest, as: UTF8.self) == expectedRemaining)
        }
    }

    @Test("parseSpaces consumes an input that is nothing but spaces")
    func parseSpacesConsumesAnInputOfOnlySpaces() throws {
        try TestUtilities.withParseInput(for: "   ") { buffer in
            try buffer.parseSpaces()
            #expect(buffer.remaining == 0)
        }
    }

    @Test("parseSpaces consumes nothing when the first byte is not a space")
    func parseSpacesConsumesNothingWhenTheFirstByteIsNotASpace() {
        TestUtilities.withParseInput(for: "a ") { buffer in
            #expect(parseErrorThrown { try buffer.parseSpaces() } is ParserError)
            #expect(buffer.remaining == 2)
        }
    }
}

// MARK: - parseUnsignedInt64

extension ParseInputCombinatorTests {
    @Test(
        "parseUnsignedInt64 parses numbers correctly",
        arguments: [
            ("12345\r", 12345, 5),
            ("18446744073709551615\r", UInt64.max, 20),
            ("12345 a", 12345, 5),
            ("18446744073709551615b", UInt64.max, 20),
        ]
    )
    func parseUnsignedInt64ParsesNumbersCorrectly(
        input: String,
        expectedResult: UInt64,
        expectedConsumed: Int
    ) throws {
        try TestUtilities.withParseInput(for: input) { buffer in
            let (id, actualConsumed) = try buffer.parseUnsignedInt64(tracker: .makeNewDefault)
            #expect(actualConsumed == expectedConsumed)
            #expect(id == expectedResult)
        }
    }

    @Test("parseUnsignedInt64 rejects a number that does not fit")
    func parseUnsignedInt64RejectsANumberThatDoesNotFit() {
        TestUtilities.withParseInput(for: "18446744073709551616\r") { buffer in
            #expect(parseErrorThrown { try buffer.parseUnsignedInt64(tracker: .makeNewDefault) } is ParserError)
        }
    }
}

// MARK: - decodeUTF8

extension ParseInputCombinatorTests {
    @Test("decodeUTF8 with ASCII string")
    func decodeUtf8WithAsciiString() throws {
        let test1 = Array("hello, world".utf8)
        #expect(try decodeUTF8(test1) == "hello, world")
    }

    @Test("decodeUTF8 with multi-byte UTF-8 characters")
    func decodeUtf8WithMultiByteUtf8Characters() throws {
        let test2: [UInt8] = [0xE2, 0x9A, 0xA1, 0xE2, 0x9A, 0xA2, 0xE2, 0x9A, 0xA3, 0xE2, 0x9A, 0xA4]
        #expect(try decodeUTF8(test2) == "⚡⚢⚣⚤")
    }

    @Test("decodeUTF8 with incomplete UTF-8 sequence")
    func decodeUtf8WithIncompleteUtf8Sequence() throws {
        let test3: [UInt8] = [0xC2]
        #expect(throws: (any Error).self) {
            try decodeUTF8(test3)
        }
    }

    @Test("decodeUTF8 with truncated multi-byte sequence")
    func decodeUtf8WithTruncatedMultiByteSequence() throws {
        let test4: [UInt8] = [0xE1, 0x80]
        #expect(throws: (any Error).self) {
            try decodeUTF8(test4)
        }
    }
}

// MARK: - matchNewline

extension ParseInputCombinatorTests {
    @Test(
        "matchNewline handles various newline formats",
        arguments: [
            "\r\n",
            "\n",
            "\r",
            " \r\n",
            " \n",
            " \r",
            "      \r\n",
            "      \n",
            "      \r",
        ]
    )
    func matchNewlineHandlesVariousNewlineFormats(newline: String) throws {
        try TestUtilities.withParseInput(for: newline + "hello, world") { buffer in
            try buffer.matchNewline()
            try buffer.matchFixed("hello, world")
        }
    }

    /// A long run of stray spaces used to cost one `composite` frame each, so more than a hundred of them
    /// threw `TooMuchRecursion`. The cursor measures the whole match ahead of the read position and
    /// advances once, so this now succeeds up to ``ParseInput/maximumStraySpaces``, and the stack no longer
    /// grows at all.
    @Test(
        "matchNewline skips a long run of stray spaces without recursing",
        arguments: [80, 200, ParseInput.maximumStraySpaces]
    )
    func matchNewlineSkipsALongRunOfStraySpaces(spaces: Int) throws {
        try TestUtilities.withParseInput(for: String(repeating: " ", count: spaces) + "\r\nhello, world") { buffer in
            try buffer.matchNewline()
            try buffer.matchFixed("hello, world")
        }
    }
}
