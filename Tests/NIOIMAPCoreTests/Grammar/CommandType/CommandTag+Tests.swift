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

@Suite("Command.Tag")
struct CommandTagTests {
    /// A tag is written to the wire verbatim, so ``Command/Tag/init(_:)`` is the only thing
    /// between a caller that builds tags from untrusted input and an injected command.
    @Test(
        "invalid tags are rejected",
        arguments: [
            "",
            "+",
            "A+1",  // ASTRING-CHAR, but not a tag char.
            "A 1",
            "A(1",
            "A{1",
            "A*1",
            "A%1",
            #"A"1"#,
            #"A\1"#,
            "Ä1",
            "A\u{7F}1",
            "A1 NOOP\r\nA2 DELETE INBOX\r\nA3",  // Would inject a whole command.
            "* BYE x\r\nA1",  // Would inject an untagged response.
        ]
    )
    func invalidTags(_ string: String) {
        #expect(Command.Tag(string) == nil)
    }

    @Test("valid tags", arguments: validTagStrings)
    func validTags(_ string: String) {
        #expect(Command.Tag(string).map { String($0) } == string)
    }

    /// Written verbatim, so every tag we accept has to parse back unchanged, in a command and in a
    /// response.
    @Test("valid tags round-trip in a command", arguments: validTagStrings)
    func commandRoundTrip(_ string: String) throws {
        let tag = try #require(Command.Tag(string))
        var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .rfc3501, loggingMode: false)
        encodeBuffer.writeCommand(TaggedCommand(tag: tag, command: .noop))
        var buffer = ParseBuffer(encodeBuffer.buffer.nextChunk().bytes)
        let parsed = try GrammarParser().parseTaggedCommand(buffer: &buffer, tracker: .testTracker)
        #expect(parsed == TaggedCommand(tag: tag, command: .noop))
    }

    @Test("valid tags round-trip in an APPEND", arguments: validTagStrings)
    func appendRoundTrip(_ string: String) throws {
        let tag = try #require(Command.Tag(string))
        var encodeBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .rfc3501, loggingMode: false)
        encodeBuffer.writeCommandStream(.append(.start(tag: tag, appendingTo: .inbox)))
        var bytes = encodeBuffer.buffer.nextChunk().bytes
        bytes.writeString(" ")
        var buffer = ParseBuffer(bytes)
        let parsed = try GrammarParser().parseAppend(buffer: &buffer, tracker: .testTracker)
        #expect(parsed == .append(.start(tag: tag, appendingTo: .inbox)))
    }

    @Test("valid tags round-trip in a tagged response", arguments: validTagStrings)
    func responseRoundTrip(_ string: String) throws {
        TestUtilities.expectRoundTrip(
            TaggedResponse(tag: try #require(Command.Tag(string)), state: .ok(.init(text: "done"))),
            terminator: "",
            encoder: { $0.writeTaggedResponse($1) },
            parser: GrammarParser().parseTaggedResponse
        )
    }

    @Test(arguments: [
        ParseFixture.tag("abc", "\r", expected: .success("abc")),
        ParseFixture.tag("abc", "+", expected: .success("abc")),
        ParseFixture.tag("+", "", expected: .failure),
        ParseFixture.tag("", "", expected: .incompleteMessage),
        // RFC 3501: tag = 1*<any ASTRING-CHAR except "+">; ASTRING-CHAR
        // inherits the CTL exclusion via ATOM-CHAR, and RFC 5234 has
        // CTL = %x00-1F / %x7F, so a tag stops at DEL and cannot start with it.
        ParseFixture.tag("ab", "\u{7F}c\r", expected: .success("ab")),
        ParseFixture.tag("\u{7F}", "", expected: .failure),
        // Stops at non-ASCII: parsed tags go through `init(unchecked:)`.
        ParseFixture.tag("ab", "ü\r", expected: .success("ab")),
    ])
    func parse(_ fixture: ParseFixture<Command.Tag>) {
        fixture.checkParsing()
    }

    #if !os(iOS) && !os(watchOS) && !os(tvOS) && !os(visionOS) && !os(Android)
    @Test("an invalid string literal traps") func stringLiteralPreconditionFailure() async {
        let result = await #expect(
            processExitsWith: ExitTest.Condition.failure,
            observing: [\.standardErrorContent],
            performing: {
                let tag: Command.Tag = "A 1"
                _ = tag
            }
        )
        TestUtilities.expectTrapMessage(result, "Invalid command tag")
    }
    #endif
}

// MARK: -

private let validTagStrings = [
    "A",
    "1",
    "A001",
    "a.b-c_d",
    "]",
    "A]1",
    "!#$&'",
    "~|`^=",
]

extension ParseFixture<Command.Tag> {
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
}
