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

@Suite("TaggedCommand")
struct TaggedCommandTests {
    @Test(arguments: [
        ParseFixture.taggedCommand("a CAPABILITY", expected: .success(.init(tag: "a", command: .capability))),
        ParseFixture.taggedCommand("1 CAPABILITY", expected: .success(.init(tag: "1", command: .capability))),
        ParseFixture.taggedCommand("a1 CAPABILITY", expected: .success(.init(tag: "a1", command: .capability))),
        ParseFixture.taggedCommand("(", "CAPABILITY", expected: .failure),
        ParseFixture.taggedCommand("a CAPABILITY", "", expected: .incompleteMessage),
    ])
    func parse(_ fixture: ParseFixture<TaggedCommand>) {
        fixture.checkParsing()
    }

    @Test("parse tagged command throws bad command") func parseTaggedCommandThrowsBadCommand() {
        // Test that the parser error occurs when parsing the command name
        var buffer1 = TestUtilities.makeParseBuffer(for: "A1 ()\r\n")
        do {
            _ = try GrammarParser().parseTaggedCommand(buffer: &buffer1, tracker: .testTracker)
            Issue.record("Expected BadCommand error to be thrown")
        } catch let error as BadCommand {
            #expect(error.commandTag == "A1")
        } catch {
            Issue.record("Expected BadCommand, got \(error)")
        }

        // Test that the parser error occurs when parsing a command component
        var buffer2 = TestUtilities.makeParseBuffer(for: "A2 ID aaaa\r\n")
        do {
            _ = try GrammarParser().parseTaggedCommand(buffer: &buffer2, tracker: .testTracker)
            Issue.record("Expected BadCommand error to be thrown")
        } catch let error as BadCommand {
            #expect(error.commandTag == "A2")
        } catch {
            Issue.record("Expected BadCommand, got \(error)")
        }

        // Make sure we still throw incomplete messages
        var buffer3 = TestUtilities.makeParseBuffer(for: "A2 LOGIN")
        #expect(throws: IncompleteMessage.self) {
            try GrammarParser().parseTaggedCommand(buffer: &buffer3, tracker: .testTracker)
        }
    }
}

// MARK: -

extension ParseFixture<TaggedCommand> {
    fileprivate static func taggedCommand(
        _ input: String,
        _ terminator: String = "\r",
        expected: Expected
    ) -> Self {
        ParseFixture(
            input: input,
            terminator: terminator,
            expected: expected,
            parser: GrammarParser().parseTaggedCommand
        )
    }
}
