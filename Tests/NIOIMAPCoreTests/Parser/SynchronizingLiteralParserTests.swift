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
import NIOTestUtils
import Testing

@Suite("SynchronizingLiteralParser")
struct SynchronizingLiteralParserTests {
    @Test(
        "single string parsing",
        arguments: [
            SingleStringFixture(
                testDescription: "straight forward case",
                input: "LOGIN \"a\" \"b\"\r\nFOO x y\r\n",
                continuationsNecessary: 0
            ),
            SingleStringFixture(
                testDescription: "single CR newline",
                input: "LOGIN \"a\" \"b\"\r",
                continuationsNecessary: 0
            ),
            SingleStringFixture(
                testDescription: "empty literals work",
                input: "LOGIN {0}\r\n {0+}\r\n {~0}\r\n {~0+}\r\n {0-}\r\n\r\nFOO x y\r\n",
                continuationsNecessary: 2
            ),
            SingleStringFixture(
                testDescription: "straight forward case with synchronising literals",
                input: "LOGIN {1}\r\nA {1}\r\nB\r\nFOO x y\r\n",
                continuationsNecessary: 2
            ),
            SingleStringFixture(
                testDescription: "straight forward case with non-synchronising literals",
                input: "LOGIN {1+}\r\nA {1+}\r\nB\r\nFOO x y\r\n",
                continuationsNecessary: 0
            ),
            SingleStringFixture(
                testDescription: "straight forward case with mixed literals",
                input: "LOGIN {1+}\r\nA {1}\r\nB\r\nFOO x y\r\n",
                continuationsNecessary: 1
            ),
            SingleStringFixture(
                testDescription: "partial commands dont make bytes visible",
                input: "LOGIN \"a\" \"b\"",
                expectedOutput: "",
                continuationsNecessary: 0
            ),
            SingleStringFixture(
                testDescription: "partial commands literals do make bytes visible 1",
                input: "LOGIN \"a\" {2}\r\n1",
                continuationsNecessary: 1
            ),
            SingleStringFixture(
                testDescription: "partial commands literals do make bytes visible 2",
                input: "LOGIN \"a\" {2}\r\n",
                continuationsNecessary: 1
            ),
            SingleStringFixture(
                testDescription: "literal data in normal literal",
                input: "{5}\r\n{0}\r\n\r\n",
                continuationsNecessary: 1
            ),
            SingleStringFixture(
                testDescription: "literal data in plus literal",
                input: "{5+}\r\n{0}\r\n\r\n",
                continuationsNecessary: 0
            ),
        ]
    )
    fileprivate func singleStringParsing(fixture: SingleStringFixture) {
        var helper = Helper()
        helper.feed(fixture.input)
        helper.assertOneParse(fixture.expectedOutput, continuationsNecessary: fixture.continuationsNecessary)
    }

    @Test("drip feed works for literals 1")
    func dripFeedWorksForLiterals1() {
        var helper = Helper()
        helper.feed("LOGIN {")
        helper.feed("1")
        helper.feed("}")
        #expect(helper.parses.last?.synchronizingLiteralCount ?? -1 == 0)
        helper.feed("\r\n")
        #expect(helper.parses.last?.synchronizingLiteralCount ?? -1 == 1)
        helper.assertMultipleParses(["", "", "", "LOGIN {1}\r\n"], continuationsNecessary: 1)
    }

    @Test("drip feed works for literals 2")
    func dripFeedWorksForLiterals2() {
        var helper = Helper()
        helper.feed("LOGIN {")
        helper.feed("1")
        helper.feed("}")
        #expect(helper.parses.last?.synchronizingLiteralCount ?? -1 == 0)
        helper.feed("\r")
        #expect(helper.parses.last?.synchronizingLiteralCount ?? -1 == 1)
        helper.assertMultipleParses(["", "", "", "LOGIN {1}\r"], continuationsNecessary: 1)
    }

    @Test("consumption works")
    func consumptionWorks() {
        var helper = Helper()
        let string = "LOGIN {1}\r\nA {1}\r\nB\r\nFOO {1}\r\nx y\r\n"
        helper.feed(string)
        helper.assertOneParse(string, continuationsNecessary: 3)
        helper.indicateConsume("LOGIN {1}\r\nA {1}\r\n")
        helper.feed("")
        helper.indicateConsume("B")
        helper.feed("")
        helper.indicateConsume("\r\n")
        helper.feed("")
        helper.indicateConsume("FOO {1}\r\nx y\r\n")
        helper.assertMultipleParses(
            [
                "LOGIN {1}\r\nA {1}\r\nB\r\nFOO {1}\r\nx y\r\n",
                "B\r\nFOO {1}\r\nx y\r\n",
                "\r\nFOO {1}\r\nx y\r\n",
                "FOO {1}\r\nx y\r\n",
            ],
            continuationsNecessary: 3
        )
    }

    @Test("drip feed works")
    func dripFeedWorks() {
        var helper = Helper()
        helper.feed("LOGIN {")
        helper.feed("1}\r\n")
        helper.feed("\n")
        helper.feed("\n")
        helper.feed("LOGIN {")
        helper.feed("1}")
        helper.feed("\r\n {2}\n\r\n\nFOO {5}\n{0}\r\n\n")
        helper.indicateConsume("LOGIN {1}\r\n\n\n")
        helper.feed("")
        helper.indicateConsume("LOGIN {1}\r\n")
        helper.feed("")
        helper.indicateConsume(" ")
        helper.feed("")
        helper.indicateConsume("{2}\r\n")
        helper.feed("")
        helper.indicateConsume("\n\n")
        helper.feed("")
        helper.indicateConsume("FOO {5}\n{0}\r\n\n")
        helper.feed("")

        helper.assertMultipleParses(
            [
                "",
                "LOGIN {1}\r\n",
                "LOGIN {1}\r\n\n",
                "LOGIN {1}\r\n\n\n",
                "LOGIN {1}\r\n\n\n",
                "LOGIN {1}\r\n\n\n",
                "LOGIN {1}\r\n\n\nLOGIN {1}\r\n {2}\n\r\n\nFOO {5}\n{0}\r\n\n",
                "LOGIN {1}\r\n {2}\n\r\n\nFOO {5}\n{0}\r\n\n",
                " {2}\n\r\n\nFOO {5}\n{0}\r\n\n",
                "{2}\n\r\n\nFOO {5}\n{0}\r\n\n",
                "\n\nFOO {5}\n{0}\r\n\n",
                "FOO {5}\n{0}\r\n\n",
                "",
            ],
            continuationsNecessary: 4
        )
    }

    @Test(
        "invalid literal syntax throws",
        arguments: [
            // "}" immediately before newline — after stripping "}" the buffer is empty,
            // so reverseParseIf("+") hits the .none branch and throws.
            "}\r\n",
            // "{}" — no digits between braces; reverseParseNumber encounters a
            // non-digit on the first attempt with magnitude == 1 and throws.
            "{}\r\n",
            // "+}" — after stripping "}" and "+" the buffer is empty when
            // reverseParseNumber is called, so the .none branch throws.
            "+}\r\n",
            // Literal size that overflows Int (19 nines on 64-bit = > Int.max).
            "{9999999999999999999}\r\n",
        ] as [String]
    )
    func invalidLiteralSyntaxThrows(input: String) {
        var parser = SynchronizingLiteralParser()
        let buffer = Array(input.utf8)
        #expect(throws: (any Error).self) {
            try parser.parseContinuationsNecessary(buffer)
        }
    }

    @Test("append followed by half command")
    func appendFollowedByHalfCommand() {
        var helper = Helper()
        helper.feed("tag APPEND box (\\Seen) {1+}\r\na\r\n")
        helper.indicateConsume("tag APPEND box (\\Seen) {1+}\r\n")
        helper.feed("")
        helper.indicateConsume("a")
        helper.feed("")
        helper.feed("t")

        helper.assertMultipleParses([
            "tag APPEND box (\\Seen) {1+}\r\na\r\n",
            "a\r\n",
            "\r\n",
            "\r\n",
        ])
    }
}

// MARK: -

extension SynchronizingLiteralParserTests {
    struct Helper {
        var parser = SynchronizingLiteralParser()
        var parses: [SynchronizingLiteralParser.FramingResult] = []
        /// Every byte fed so far, including the ones the caller has said it consumed.
        var accumulator: [UInt8] = []
        /// How far into `accumulator` the caller has consumed.
        var readerIndex = 0
        var consumptions: [(numberOfPriorParses: Int, consumption: Int)] = []

        mutating func feed(_ string: String) {
            accumulator.append(contentsOf: string.utf8)
            do {
                parses.append(
                    try parser.parseContinuationsNecessary(withGarbagePrefix(accumulator[readerIndex...]))
                )
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }

        mutating func indicateConsume(_ string: String) {
            consumptions.append((parses.count, string.utf8.count))
            readerIndex += string.utf8.count
            parser.consumed(string.utf8.count)
        }

        func assertMultipleParses(
            _ expectedStrings: [String],
            continuationsNecessary: Int = 0,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            guard expectedStrings.count == parses.count else {
                Issue.record(
                    "Unexpected number of parses: \(parses.count), expected: \(expectedStrings.count)",
                    sourceLocation: sourceLocation
                )
                return
            }

            // Rewind to where the reader was before any of these parses consumed anything, then walk
            // it forward one parse at a time.
            let initialAllByteReader = readerIndex - consumptions.map(\.consumption).reduce(0, +)
            var allBytesReader = initialAllByteReader
            var continuations = 0
            for expected in expectedStrings.enumerated() {
                let parse = parses[expected.offset]
                let expectedUTF8 = Array(expected.element.utf8)
                let actual = Array(accumulator[allBytesReader...].prefix(parse.maximumValidBytes))
                #expect(
                    expectedUTF8 == actual,
                    "parse \(expected.0): \(String(decoding: expectedUTF8, as: UTF8.self)) != \(String(decoding: actual, as: UTF8.self))",
                    sourceLocation: sourceLocation
                )
                #expect(parse.synchronizingLiteralCount >= 0, sourceLocation: sourceLocation)
                continuations += parse.synchronizingLiteralCount

                allBytesReader =
                    consumptions.filter {
                        $0.numberOfPriorParses <= expected.offset + 1
                    }.map(\.consumption).reduce(0, +) + initialAllByteReader
            }
            #expect(
                continuationsNecessary == continuations,
                "wrong number of continuations",
                sourceLocation: sourceLocation
            )
        }

        func assertOneParse(
            _ string: String,
            continuationsNecessary: Int = 0,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            #expect(parses.count == 1, sourceLocation: sourceLocation)
            guard let parse = parses.first else {
                Issue.record("no parses found", sourceLocation: sourceLocation)
                return
            }
            let expected = Array(string.utf8)
            let actual = Array(accumulator[readerIndex...].prefix(parse.maximumValidBytes))
            #expect(
                expected == actual,
                "\(String(decoding: expected, as: UTF8.self)) != \(String(decoding: actual, as: UTF8.self))",
                sourceLocation: sourceLocation
            )
            #expect(
                continuationsNecessary == parse.synchronizingLiteralCount,
                sourceLocation: sourceLocation
            )
        }

        /// The same bytes, preceded in the same allocation by junk the parser must not look at.
        ///
        /// A parser that reads from the start of its region's *storage* rather than from where the
        /// region begins sees the junk and fails; one that respects the region cannot tell the
        /// difference. This is what a `ByteBuffer`'s reader index used to express here.
        private func withGarbagePrefix(_ bytes: ArraySlice<UInt8>) -> ArraySlice<UInt8> {
            let garbageByteCount = (0..<32).randomElement() ?? 0
            var padded = Array(repeating: UInt8(ascii: "X"), count: garbageByteCount)
            padded.append(contentsOf: bytes)
            return padded[garbageByteCount...]
        }
    }
}

private struct SingleStringFixture: CustomTestArgumentEncodable, CustomTestStringConvertible {
    var testDescription: String
    var input: String
    var expectedOutput: String
    var continuationsNecessary: Int = 0

    init(
        testDescription: String,
        input: String,
        expectedOutput: String? = nil,
        continuationsNecessary: Int = 0
    ) {
        self.testDescription = testDescription
        self.input = input
        self.expectedOutput = expectedOutput ?? input
        self.continuationsNecessary = continuationsNecessary
    }

    func encodeTestArgument(to encoder: some Encoder) throws {
        try input.encode(to: encoder)
    }

    var description: String {
        testDescription
    }
}
