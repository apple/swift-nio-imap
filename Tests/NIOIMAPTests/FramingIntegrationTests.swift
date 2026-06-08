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
@testable import NIOIMAP
@testable import NIOIMAPCore
import NIOTestUtils

import Testing

@Suite struct FramingIntegrationTests {
    @Test("simple commands")
    func simpleCommands() {
        let helper = Helper()
        helper.writeInbound("A1 NOOP\r\n")
        helper.assertInbound(.tagged(.init(tag: "A1", command: .noop)))
    }

    @Test("literal dump")
    func literalDump() {
        let helper = Helper()
        helper.writeInbound("A1 LOGIN {3}\r\n123 {3}\r\n456\r\n")
        helper.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }

    @Test("literal streaming")
    func literalStreaming() {
        let helper = Helper()
        helper.writeInbound("A1 LOGIN {3}\r\n123 ")
        helper.writeInbound("{3}\r\n456\r\n")
        helper.assertInbound(.tagged(.init(tag: "A1", command: .login(username: "123", password: "456"))))
    }

    // Regression test: a bare CR ending one inbound segment, followed by a segment terminated by a
    // bare LF, used to abort the whole process via a `precondition` in `FramingParser`. Because
    // `FrameDecoder` can be installed ahead of any authentication handler, this was reachable by
    // any connecting client, so we drive raw `FramingResult`s rather than parsed commands.
    @Test("split bare CR does not crash the frame decoder")
    func splitBareCRDoesNotCrashFrameDecoder() {
        let channel = EmbeddedChannel(handler: ByteToMessageHandler(FrameDecoder()))

        #expect(throws: Never.self) { try channel.writeInbound(ByteBuffer(string: "A1 NOOP\r")) }
        #expect(throws: Never.self) { try channel.writeInbound(ByteBuffer(string: "A2 NOOP\n")) }

        var first: FramingResult?
        var second: FramingResult?
        #expect(throws: Never.self) { first = try channel.readInbound(as: FramingResult.self) }
        #expect(throws: Never.self) { second = try channel.readInbound(as: FramingResult.self) }
        #expect(first == .complete("A1 NOOP\r"))
        #expect(second == .complete("A2 NOOP\n"))

        #expect(throws: Never.self) { _ = try channel.finish() }
    }

    // MARK: - Well-formed input parses identically regardless of how it is split

    // The core robustness property: a well-formed IMAP byte stream must parse into the *same*
    // sequence of `CommandStreamPart`s — and never crash — no matter where the network happens to
    // split it. We assert this exhaustively at every byte boundary (and, separately, at every pair
    // of boundaries), which automatically exercises every CR/LF split position including the
    // bare-CR-at-a-segment-boundary case.
    //
    // We compare at the *parsed* layer rather than the raw framing layer on purpose: a `CR | LF`
    // split legitimately drops the skipped LF and a split literal body is chunked differently, so
    // the raw frames differ — but the parsed commands must not.
    @Test("well-formed input parses identically at every single split")
    func wellFormedInputParsesIdenticallyAtEverySingleSplit() {
        for entry in Self.wellFormedCorpus {
            let bytes = Array(entry.input.utf8)

            // Sanity: the un-split stream parses to the expected commands.
            #expect(
                self.parsedParts(of: bytes, splittingAt: []) == entry.expected,
                "unsplit: \(entry.input.debugDescription)"
            )

            // Every two-way split (both segments non-empty) must agree.
            for splitIndex in 1..<bytes.count {
                let parts = self.parsedParts(of: bytes, splittingAt: [splitIndex])
                #expect(parts == entry.expected, "split \(entry.input.debugDescription) at byte \(splitIndex)")
            }
        }
    }

    @Test("well-formed input parses identically at every pair of splits")
    func wellFormedInputParsesIdenticallyAtEveryPairOfSplits() {
        // Three-way splits catch desyncs that only appear when a boundary lands inside a frame that
        // is itself already straddling a boundary. Restricted to a couple of representative streams
        // (a CRLF command and a literal) to keep the O(n²) sweep cheap.
        for entry in Self.wellFormedCorpus where entry.exhaustivePairs {
            let bytes = Array(entry.input.utf8)
            for first in 1..<bytes.count {
                for second in (first + 1)..<bytes.count {
                    let parts = self.parsedParts(of: bytes, splittingAt: [first, second])
                    #expect(
                        parts == entry.expected,
                        "split \(entry.input.debugDescription) at bytes \(first), \(second)"
                    )
                }
            }
        }
    }
}

extension FramingIntegrationTests {
    /// A well-formed IMAP stream, the commands it must parse into, and whether it should also be
    /// swept with the (more expensive) every-pair-of-splits test.
    struct CorpusEntry {
        var input: String
        var expected: [CommandStreamPart]
        var exhaustivePairs: Bool = false
    }

    static let wellFormedCorpus: [CorpusEntry] = [
        // A single command with a conforming CRLF terminator.
        CorpusEntry(
            input: "A1 NOOP\r\n",
            expected: [.tagged(.init(tag: "A1", command: .noop))],
            exhaustivePairs: true
        ),
        // The same command with a non-conforming bare LF (Unix) terminator.
        CorpusEntry(
            input: "A1 NOOP\n",
            expected: [.tagged(.init(tag: "A1", command: .noop))]
        ),
        // Two commands back to back, CRLF-terminated.
        CorpusEntry(
            input: "a1 NOOP\r\nb2 NOOP\r\n",
            expected: [
                .tagged(.init(tag: "a1", command: .noop)),
                .tagged(.init(tag: "b2", command: .noop)),
            ]
        ),
        // Two commands back to back, bare-LF terminated.
        CorpusEntry(
            input: "a1 NOOP\nb2 NOOP\n",
            expected: [
                .tagged(.init(tag: "a1", command: .noop)),
                .tagged(.init(tag: "b2", command: .noop)),
            ]
        ),
        // Two commands where the first is terminated by a bare CR and the second by a bare LF.
        // Splitting immediately after that bare CR is the exact bare-CR-desync repro, so this
        // entry also regression-guards the fix at one of its split points.
        CorpusEntry(
            input: "A1 NOOP\rA2 NOOP\n",
            expected: [
                .tagged(.init(tag: "A1", command: .noop)),
                .tagged(.init(tag: "A2", command: .noop)),
            ],
            exhaustivePairs: true
        ),
        // A command carrying literals — the literal body must reassemble across any boundary.
        CorpusEntry(
            input: "A1 LOGIN {3}\r\n123 {3}\r\n456\r\n",
            expected: [.tagged(.init(tag: "A1", command: .login(username: "123", password: "456")))],
            exhaustivePairs: true
        ),
        // A command carrying quoted strings.
        CorpusEntry(
            input: #"A1 LOGIN "user" "pass"\#r\#n"#,
            expected: [.tagged(.init(tag: "A1", command: .login(username: "user", password: "pass")))]
        ),
    ]

    /// Feeds `bytes` to a fresh `FrameDecoder` + `IMAPServerHandler` pipeline, broken into segments
    /// at the given (sorted, strictly increasing) byte boundaries, and returns every parsed
    /// `CommandStreamPart`. Any throw — including a process-aborting crash — fails the test.
    func parsedParts(
        of bytes: [UInt8],
        splittingAt boundaries: [Int],
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> [CommandStreamPart] {
        let channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), IMAPServerHandler()])
        var parts: [CommandStreamPart] = []

        var start = 0
        for end in boundaries + [bytes.count] {
            let segment = Array(bytes[start..<end])
            start = end
            #expect(throws: Never.self, sourceLocation: sourceLocation) {
                try channel.writeInbound(ByteBuffer(bytes: segment))
            }
            while true {
                var part: CommandStreamPart?
                #expect(throws: Never.self, sourceLocation: sourceLocation) {
                    part = try channel.readInbound(as: CommandStreamPart.self)
                }
                guard let part else { break }
                parts.append(part)
            }
        }

        _ = try? channel.finish()
        return parts
    }
}

extension FramingIntegrationTests {
    struct Helper {
        var channel = EmbeddedChannel(handlers: [ByteToMessageHandler(FrameDecoder()), IMAPServerHandler()])
    }
}

extension FramingIntegrationTests.Helper {
    func writeInbound(_ buffer: ByteBuffer, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(throws: Never.self, sourceLocation: sourceLocation) { try self.channel.writeInbound(buffer) }
    }

    func assertInbound(_ command: CommandStreamPart, sourceLocation: SourceLocation = #_sourceLocation) {
        var _inbound: CommandStreamPart?
        #expect(throws: Never.self, sourceLocation: sourceLocation) {
            _inbound = try self.channel.readInbound(as: CommandStreamPart.self)
        }

        guard let inbound = _inbound else {
            Issue.record("Expected non-nil inbound value", sourceLocation: sourceLocation)
            return
        }

        #expect(command == inbound)
    }
}
