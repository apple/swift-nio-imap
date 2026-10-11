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

@Suite("ResponseText")
struct ResponseTextTests {
    /// Written verbatim, so all text we accept has to parse back unchanged, with and without a code.
    @Test("valid text round-trips", arguments: validTextStrings)
    func validTextRoundTrips(_ string: String) {
        for code in [nil, ResponseTextCode.alert] {
            TestUtilities.expectRoundTrip(
                ResponseText(code: code, text: string),
                terminator: "\r\n",
                encoder: { $0.writeResponseText($1) },
                parser: GrammarParser().parseResponseText
            )
        }
    }

    #if DEBUG && !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    /// Text is written to the wire verbatim, so a server that echoes untrusted input could inject a
    /// whole response.
    @Test(
        "writing invalid text traps",
        arguments: [
            "a\rb",
            "a\nb",
            "a\u{0}b",
            "No mailbox x\r\n* BYE pwned",
        ]
    )
    func invalidTextTraps(_ string: String) async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: { [string = string as String] in
                var buffer = EncodeBuffer.serverEncodeBuffer(
                    buffer: ByteBuffer(),
                    options: ResponseEncodingOptions(),
                    loggingMode: false
                )
                buffer.writeResponseText(ResponseText(text: string))
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid text")
    }
    #endif

    @Test(arguments: [
        EncodeFixture.responseText(.init(code: nil, text: "buffer"), "buffer"),
        EncodeFixture.responseText(.init(code: .alert, text: "buffer"), "[ALERT] buffer"),
        EncodeFixture.responseText(.init(code: nil, text: ""), " "),
        EncodeFixture.responseText(.init(code: .alert, text: ""), "[ALERT]  "),
    ])
    func encode(_ fixture: EncodeFixture<ResponseText>) {
        fixture.checkEncoding()
    }

    @Test(arguments: [
        ParseFixture.responseText("", expected: .success(.init(code: nil, text: ""))),
        ParseFixture.responseText(" ", expected: .success(.init(code: nil, text: ""))),
        ParseFixture.responseText("text", expected: .success(.init(code: nil, text: "text"))),
        ParseFixture.responseText(" text", expected: .success(.init(code: nil, text: "text"))),
        ParseFixture.responseText("[UNSEEN 1]", expected: .success(.init(code: .unseen(1), text: ""))),
        ParseFixture.responseText("[UNSEEN 2] ", expected: .success(.init(code: .unseen(2), text: ""))),
        ParseFixture.responseText(
            "[UNSEEN 2] some text",
            expected: .success(.init(code: .unseen(2), text: "some text"))
        ),
        ParseFixture.responseText(
            "[UIDVALIDITY 1561789793]",
            expected: .success(.init(code: .uidValidity(1_561_789_793), text: ""))
        ),
        ParseFixture.responseText("[UIDNEXT 171]", expected: .success(.init(code: .uidNext(171), text: ""))),
        ParseFixture.responseText("Grüezi 🇨🇭", expected: .success(.init(code: nil, text: "Grüezi 🇨🇭"))),
    ])
    func parse(_ fixture: ParseFixture<ResponseText>) {
        fixture.checkParsing()
    }

    @Test("non-UTF-8 text fails to parse")
    func parseLatin1() {
        // Latin-1 `ü`.
        var buffer = ParseBuffer(ByteBuffer(bytes: [UInt8(ascii: "a"), 0xFC, UInt8(ascii: "\r")]))
        #expect(throws: ParserError.self) {
            try GrammarParser().parseResponseText(buffer: &buffer, tracker: .testTracker)
        }
    }

    @Test(
        "custom debug string convertible",
        arguments: [
            DebugStringFixture(sut: ResponseText(code: nil, text: "buffer"), expected: "buffer"),
            DebugStringFixture(sut: ResponseText(code: .alert, text: "buffer"), expected: "[ALERT] buffer"),
        ]
    )
    func customDebugStringConvertible(_ fixture: DebugStringFixture<ResponseText>) {
        fixture.check()
    }
}

// MARK: -

private let validTextStrings = [
    "",
    "a",
    "CAPABILITY completed",
    "a  b ",
    "a\tb",
    "[a",
    "a]",
    "Grüezi",
    "日本語",
    "🇨🇭",
]

extension EncodeFixture<ResponseText> {
    fileprivate static func responseText(
        _ input: ResponseText,
        _ expectedString: String
    ) -> Self {
        EncodeFixture(
            input: input,
            bufferKind: .defaultServer,
            expectedString: expectedString,
            encoder: { $0.writeResponseText($1) }
        )
    }
}

extension ParseFixture<ResponseText> {
    fileprivate static func responseText(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseResponseText
        )
    }
}
