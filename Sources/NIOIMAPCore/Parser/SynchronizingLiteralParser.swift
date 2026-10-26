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

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView

/// A parser dedicated to handling synchronizing literals.
///
/// Synchronizing literals are defined in RFC 3501 Section 4.3. When a client sends
/// a command containing a literal, it first sends `{size}` and then waits for a `+`
/// continuation response from the server before sending the actual literal bytes.
///
/// Scans command data to identify literal sizes and locations, determining
/// which bytes must wait for continuation responses and which can be sent immediately.
/// It distinguishes between:
/// - Synchronizing literals (`{100}`) - require continuation
/// - Non-synchronizing literals (`{100+}`, `{100-}`) - no continuation needed
/// - Binary literals (`~{100}`) - binary data format
///
/// Like ``CommandParser``, this expects correctly framed input. For example, if a literal
/// header's CRLF is split across reads, the orphaned LF is counted as a literal byte.
///
/// - SeeAlso: [RFC 3501 Section 4.3.3](https://datatracker.ietf.org/doc/html/rfc3501#section-4.3.3),
///   ``CommandParser``
public struct SynchronizingLiteralParser: Sendable {
    private var offset = 0
    private var synchronisingLiterals = 0
    private var state = State.waitingForCompleteLine

    private enum State: Hashable, Sendable {
        case waitingForCompleteLine
        case waitingForLiteralBytes(Int)
    }

    private enum LineFragmentType: Sendable {
        case completeLine
        case synchronisingLiteral(Int)
        case nonSynchronisingLiteral(Int)
    }

    /// Creates a new synchronizing literal parser.
    public init() {}

    /// Contains information on the result of a call to `parseContinuationsNecessary`.
    public struct FramingResult: Sendable {
        /// The maximum number of bytes that can be consumed by the command parser until continuation responses are needed.
        ///
        /// Once this many bytes have been processed, any remaining synchronizing literals in the command
        /// require continuation requests before they can be sent.
        public var maximumValidBytes: Int

        /// How many synchronising literals are in the frame.
        public var synchronizingLiteralCount: Int
    }

    /// Looks for continuations to determine how many there should be, if any, and how many bytes can be consumed before more data is required.
    /// - parameter buffer: The bytes to scan. Note that this is not a consuming function.
    /// - returns: A `FramingResult` containing details of the parse.
    public mutating func parseContinuationsNecessary(_ buffer: some ParserInputBuffer) throws -> FramingResult {
        try buffer.withParseInput { try self.parseContinuationsNecessary($0) }
    }

    /// The framing pass, over a cursor the caller has already gathered.
    ///
    /// This is what the command parser calls, so that framing the input and parsing it share one gather
    /// rather than each paying for their own. It reads through `input` without consuming anything: every
    /// index below is a distance from the cursor's read position, and `offset` — which persists across
    /// calls, and is walked back by ``consumed(_:)`` — is one of them.
    internal mutating func parseContinuationsNecessary(_ input: borrowing ParseInput) throws -> FramingResult {
        let count = input.remaining
        var lastOffset = self.offset
        repeat {
            switch self.state {
            case .waitingForCompleteLine:
                if let lineEnd = Self.findLineEnd(input, from: self.offset) {
                    self.offset = lineEnd
                    switch try Self.lineFragmentType(input, endingAt: lineEnd) {
                    case .synchronisingLiteral(let length):
                        self.synchronisingLiterals += 1
                        fallthrough
                    case .nonSynchronisingLiteral(let length):
                        if length > 0 {
                            self.state = .waitingForLiteralBytes(length)
                        } else {
                            assert(self.state == .waitingForCompleteLine)
                        }
                    case .completeLine:
                        ()  // nothing to do
                    }
                }
            case .waitingForLiteralBytes(let literalBytesLeft):
                let remainingBytes = count - self.offset
                if remainingBytes >= literalBytesLeft {
                    self.state = .waitingForCompleteLine
                    self.offset += literalBytesLeft
                } else {
                    let newLiteralBytesLeft = literalBytesLeft - remainingBytes
                    assert(newLiteralBytesLeft > 0, "\(newLiteralBytesLeft)")
                    self.state = .waitingForLiteralBytes(newLiteralBytesLeft)
                    self.offset += remainingBytes
                }
            }
            guard lastOffset < self.offset, self.offset < count else {
                let synchronisingLiterals = self.synchronisingLiterals
                self.synchronisingLiterals = 0
                return FramingResult(
                    maximumValidBytes: self.offset,
                    synchronizingLiteralCount: synchronisingLiterals
                )
            }
            lastOffset = self.offset
        } while true
    }

    /// Tells the parser that a number of bytes was consumed.
    /// - parameter numberOfBytes: How many bytes were successfully consumed.
    public mutating func consumed(_ numberOfBytes: Int) {
        precondition(self.offset >= numberOfBytes, "offset=\(self.offset), numberOfBytes consumed=\(numberOfBytes)")
        self.offset -= numberOfBytes
    }
}

// MARK: - Scanning

extension SynchronizingLiteralParser {
    /// How far past `start` the next line ending finishes, or `nil` if no line has arrived yet.
    ///
    /// A CR followed by an LF counts as one ending; a lone CR or LF ends the line on its own, because a
    /// CR that turns out to be half of a CRLF whose LF has not arrived yet is indistinguishable from a
    /// server that sends bare CRs, and the command parser copes with either.
    private static func findLineEnd(_ input: borrowing ParseInput, from start: Int) -> Int? {
        var walker = copy input
        walker.advance(by: start)
        // One pointer-hoisted scan per region rather than a byte at a time through the cursor: this runs
        // over every command line the server receives.
        guard let run = walker.scanWhile({ $0 != UInt8(ascii: "\r") && $0 != UInt8(ascii: "\n") }) else {
            return nil
        }
        let first = start + run
        guard input.peek(at: first) == UInt8(ascii: "\r") else {
            return first + 1
        }
        guard input.peek(at: first + 1) == UInt8(ascii: "\n") else {
            return first + 1
        }
        return first + 2
    }

    /// What kind of line ends at `end`, read backwards from there.
    ///
    /// Backwards, because a literal announces itself at the *end* of the line it is on — `{123}` or
    /// `{123+}` — and because the interesting part is a handful of bytes however long the line is. `end`
    /// is exclusive, and the fragment starts at the cursor's read position, so an `end` that walks down
    /// to zero means the line was nothing but its ending.
    private static func lineFragmentType(
        _ input: borrowing ParseInput,
        endingAt end: Int
    ) throws -> LineFragmentType {
        var end = end
        assert(end > 0, "a line ending at \(end) has no bytes")
        try reverseParseTrailingNewlines(input, &end)
        guard end > 0 else {
            return .completeLine  // this is just an empty line
        }
        guard try reverseParseIf(UInt8(ascii: "}"), input, &end) else {
            return .completeLine
        }
        guard
            try reverseParseIf(UInt8(ascii: "+"), input, &end)
                || reverseParseIf(UInt8(ascii: "-"), input, &end)
        else {
            let number = try reverseParseNumber(input, &end)
            return .synchronisingLiteral(number)
        }
        let number = try reverseParseNumber(input, &end)
        return .nonSynchronisingLiteral(number)
    }

    private static func reverseParseTrailingNewlines(_ input: borrowing ParseInput, _ end: inout Int) throws {
        let last = input.peek(at: end - 1)
        let secondToLast = end >= 2 ? input.peek(at: end - 2) : nil
        switch (secondToLast, last) {
        case (UInt8(ascii: "\r"), UInt8(ascii: "\n")):
            end -= 2
        case (_, UInt8(ascii: "\n")):
            end -= 1
        case (_, UInt8(ascii: "\r")):
            end -= 1
        default:
            throw ParserError()
        }
    }

    private static func reverseParseIf(
        _ char: UInt8,
        _ input: borrowing ParseInput,
        _ end: inout Int
    ) throws -> Bool {
        guard end > 0 else {
            throw ParserError(hint: "whilst looking for \(char), found no bytes")
        }
        switch input.peek(at: end - 1) {
        case .some(char):
            end -= 1
            return true
        case .some:
            return false
        case .none:
            throw ParserError(hint: "whilst looking for \(char), found no bytes")
        }
    }

    private static func reverseParseNumber(_ input: borrowing ParseInput, _ end: inout Int) throws -> Int {
        var current = 0
        var magnitude = 1
        while true {
            switch end > 0 ? input.peek(at: end - 1) : nil {
            case .some(let digit) where (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(digit):
                let (newCurrent, currentOverflowed) = current.addingReportingOverflow(
                    (magnitude * Int(digit - UInt8(ascii: "0")))
                )
                if currentOverflowed {
                    throw ParserError(hint: "Overflow")
                }
                current = newCurrent
                let (newMagnitude, magnitudeOverflowed) = magnitude.multipliedReportingOverflow(by: 10)
                if magnitudeOverflowed {
                    throw ParserError(hint: "Overflow")
                }
                magnitude = newMagnitude
                end -= 1
            case .some:
                guard magnitude == 1 else {
                    return current
                }
                throw ParserError()
            case .none:
                throw ParserError()
            }
        }
    }
}
