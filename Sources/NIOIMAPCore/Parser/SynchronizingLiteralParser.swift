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

/// A parser dedicated to handling syncrhonising literals.
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

    /// Creates a new `SynchronisingLiteralParser`.
    public init() {}

    private static func reverseParseTrailingNewlines(_ buffer: inout ByteBuffer) throws {
        switch (buffer.readableBytesView.reversed().dropFirst().first, buffer.readableBytesView.last) {
        case (UInt8(ascii: "\r"), UInt8(ascii: "\n")):
            buffer.moveWriterIndex(to: buffer.writerIndex - 2)
        case (_, UInt8(ascii: "\n")):
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
        case (_, UInt8(ascii: "\r")):
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
        default:
            throw ParserError()
        }
    }

    private static func reverseParseIf(_ char: UInt8, _ buffer: inout ByteBuffer) throws -> Bool {
        switch buffer.readableBytesView.last {
        case .some(char):
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
            return true
        case .some:
            return false
        case .none:
            throw ParserError(hint: "whilst looking for \(char), found no bytes")
        }
    }

    private static func reverseParseNumber(_ buffer: inout ByteBuffer) throws -> Int {
        var current = 0
        var magnitude = 1
        while true {
            switch buffer.readableBytesView.last {
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
                buffer.moveWriterIndex(to: buffer.writerIndex - 1)
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

    private static func lineFragmentType(_ fragment: ByteBufferView) throws -> LineFragmentType {
        var fragment = ByteBuffer(fragment)
        assert(fragment.readableBytes > 0, "\(fragment)")
        try reverseParseTrailingNewlines(&fragment)
        guard fragment.readableBytes > 0 else {
            return .completeLine  // this is just an empty line
        }
        guard try reverseParseIf(UInt8(ascii: "}"), &fragment) else {
            return .completeLine
        }
        guard try reverseParseIf(UInt8(ascii: "+"), &fragment) || reverseParseIf(UInt8(ascii: "-"), &fragment) else {
            let number = try reverseParseNumber(&fragment)
            return .synchronisingLiteral(number)
        }
        let number = try reverseParseNumber(&fragment)
        return .nonSynchronisingLiteral(number)
    }

    /// Contains information on the result of a call to `parseContinuationsNecessary`.
    public struct FramingResult: Sendable {
        /// The maximum number of bytes that can be consumed by a `ResponseParser` until more data is required.
        public var maximumValidBytes: Int

        /// How many synchronising literals are in the frame.
        public var synchronizingLiteralCount: Int
    }

    /// Looks for continuations to determine how many there should be, if any, and how many bytes can be consumed before more data is required.
    /// - parameter buffer: The `ByteBuffer` to scan. Note that this is not a consuming function.
    /// - returns: A `FramingResult` containing details of the parse.
    public mutating func parseContinuationsNecessary(_ buffer: ByteBuffer) throws -> FramingResult {
        var lastOffset = self.offset
        repeat {
            switch self.state {
            case .waitingForCompleteLine:
                if let newlineIndex = buffer.readableBytesView[(buffer.readableBytesView.startIndex + self.offset)...]
                    .findNewlineIndex()
                {
                    self.offset = newlineIndex - buffer.readableBytesView.startIndex + 1
                    switch try Self.lineFragmentType(buffer.readableBytesView[...newlineIndex]) {
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
                let remainingBytes =
                    buffer.readableBytesView.endIndex - (buffer.readableBytesView.startIndex + self.offset)
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
            guard lastOffset < self.offset, self.offset < buffer.readableBytesView.endIndex else {
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

extension ByteBufferView {
    fileprivate func findNewlineIndex() -> Index? {
        guard let first = firstIndex(where: { $0 == UInt8(ascii: "\n") || $0 == UInt8(ascii: "\r") }) else {
            return nil
        }
        guard self[first] == UInt8(ascii: "\r") else {
            return first
        }
        let second = index(after: first)
        guard second < endIndex else {
            return first
        }
        guard self[second] == UInt8(ascii: "\n") else {
            return first
        }
        return second
    }
}
