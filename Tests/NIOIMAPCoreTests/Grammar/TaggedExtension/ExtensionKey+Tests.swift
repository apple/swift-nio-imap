//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
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

@Suite("ExtensionKey")
struct ExtensionKeyTests {
    /// A label is written to the wire verbatim, so ``ExtensionKey/init(_:)`` is the only
    /// thing between a caller that builds labels from untrusted input and an injected command.
    @Test(
        "invalid labels are rejected",
        arguments: [
            "",  // `tagged-label-fchar *tagged-label-char`.
            "1a",  // DIGIT isn't a `tagged-label-fchar`.
            ":a",  // Nor is ":".
            "a b",
            "a(b",
            "a+b",  // ATOM-CHAR, but not a `tagged-label-char`.
            "a/b",
            "a*b",
            #"a"b"#,
            #"a\b"#,
            "GRÜEZI",
            "a\u{7F}b",
            "X\r\nA2 DELETE INBOX\r\nA3 NOOP",  // Would inject a whole command.
        ]
    )
    func invalidLabels(_ string: String) {
        #expect(ExtensionKey<SelectParameter>(string) == nil)
    }

    @Test("valid labels", arguments: validLabelStrings)
    func validLabels(_ string: String) {
        #expect(ExtensionKey<SelectParameter>(string).map { String($0) } == string)
    }

    /// Written verbatim, so every label we accept has to parse back unchanged — in each shape the
    /// label is written in.
    @Test("valid labels round-trip as a parameter", arguments: validLabelStrings)
    func validLabelsRoundTripAsParameter(_ string: String) throws {
        let label = try #require(ExtensionKey<SelectParameter>(string))
        TestUtilities.expectRoundTrip(
            KeyValue<ExtensionKey<SelectParameter>, ParameterValue?>(key: label, value: nil),
            terminator: "\r\n",
            encoder: { $0.writeParameter($1) },
            parser: GrammarParser().parseParameter
        )
        TestUtilities.expectRoundTrip(
            KeyValue<ExtensionKey<SelectParameter>, ParameterValue?>(key: label, value: .sequence(.set([1]))),
            terminator: "\r\n",
            encoder: { $0.writeParameter($1) },
            parser: GrammarParser().parseParameter
        )
    }

    @Test("valid labels round-trip as a tagged extension", arguments: validLabelStrings)
    func validLabelsRoundTripAsTaggedExtension(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            KeyValue<ExtensionKey<SelectParameter>, ParameterValue>(
                key: try #require(ExtensionKey<SelectParameter>(string)),
                value: .sequence(.set([1]))
            ),
            terminator: "\r\n",
            encoder: { $0.writeTaggedExtension($1) },
            parser: GrammarParser().parseTaggedExtension
        )
    }

    @Test("valid labels round-trip as search return data", arguments: validLabelStrings)
    func validLabelsRoundTripAsSearchReturnData(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            KeyValue<ExtensionKey<SearchReturnData>, ParameterValue>(
                key: try #require(ExtensionKey<SearchReturnData>(string)),
                value: .sequence(.set([1]))
            ),
            terminator: "\r\n",
            encoder: { $0.writeSearchReturnDataExtension($1) },
            parser: GrammarParser().parseSearchReturnDataExtension
        )
    }

    @Test("valid labels round-trip as a search return option", arguments: validLabelStrings)
    func validLabelsRoundTripAsSearchReturnOption(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            KeyValue<ExtensionKey<SearchReturnOption>, ParameterValue?>(
                key: try #require(ExtensionKey<SearchReturnOption>(string)),
                value: .sequence(.set([1]))
            ),
            terminator: "\r\n",
            encoder: { $0.writeSearchReturnOptionExtension($1) },
            parser: GrammarParser().parseSearchReturnOptionExtension
        )
    }

    @Test(arguments: [
        ParseFixture.label("a", " ", expected: .success("a")),
        ParseFixture.label("X-GM:1.a_b", " ", expected: .success("X-GM:1.a_b")),
        // Stops at `+`: parsed labels go through `init(unchecked:)`.
        ParseFixture.label("a", "+b", expected: .success("a")),
        ParseFixture.label("1a", " ", expected: .failure),
    ])
    func parse(_ fixture: ParseFixture<ExtensionKey<SelectParameter>>) {
        fixture.checkParsing()
    }

    /// RFC 4466 §3: labels are case-insensitive. The stored case is kept for the wire.
    @Test("compares case-insensitively, keeps case")
    func caseInsensitive() {
        let lower: ExtensionKey<SelectParameter> = "x-gm:a"
        let upper: ExtensionKey<SelectParameter> = "X-GM:A"
        #expect(lower == upper)
        #expect(lower.hashValue == upper.hashValue)
        #expect(Set([lower, upper]).count == 1)
        #expect([lower: 1][upper] == 1)
        #expect(lower != "X-GM:B")
        #expect(String(lower) == "x-gm:a")
    }

    /// `==` ignores case, so round-trip tests can't catch a parser that changes it.
    @Test("parsing keeps case")
    func parseKeepsCase() throws {
        var buffer = ParseBuffer(ByteBuffer(string: "x-gm:a "))
        let parsed: ExtensionKey<SelectParameter> =
            try GrammarParser().parseParameterName(buffer: &buffer, tracker: .testTracker)
        #expect(String(parsed) == "x-gm:a")
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let label: ExtensionKey<SelectParameter> = "a b"
                _ = label
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid tagged extension label")
    }
    #endif
}

// MARK: -

private let validLabelStrings = [
    "a",
    "CONDSTORE",
    "-",
    "_x",
    ".x",
    "X-GM:1.a_b",
]

extension ParseFixture<ExtensionKey<SelectParameter>> {
    fileprivate static func label(
        _ input: String,
        _ terminator: String,
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseParameterName
        )
    }
}
