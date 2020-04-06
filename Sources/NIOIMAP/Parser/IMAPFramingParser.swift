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

extension Optional where Wrapped == ByteBuffer {
    mutating func append(_ buffer: inout ByteBuffer) {
        switch self {
        case .none:
            self = buffer
        case .some(var existing):
            existing.writeBuffer(&buffer)
            self = existing
        }
    }
}

internal struct IMAPFramingParser {
    internal let bufferSizeLimit: Int
    private var accumulator: ByteBuffer?
    private var state = State.waitingForWholeLine

    internal struct ParseResult {
        var line: ByteBuffer?
        var numberOfContinuationRequestsToSend: Int
    }

    private enum LineFragmentType {
        case completeLine
        case synchronisingLiteral(Int)
        case nonSynchronisingLiteral(Int)
    }

    private enum State: Equatable {
        case waitingForWholeLine
        case waitingForBytes(Int)
    }

    init(bufferSizeLimit: Int) {
        self.bufferSizeLimit = bufferSizeLimit
    }

    private func reverseParseTrailingNewlines(_ buffer: inout ByteBuffer) throws {
        switch (buffer.readableBytesView.reversed().dropFirst().first, buffer.readableBytesView.last) {
        case (UInt8(ascii: "\r"), UInt8(ascii: "\n")):
            buffer.moveWriterIndex(to: buffer.writerIndex - 2)
        case (_, UInt8(ascii: "\n")):
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
        default:
            throw ParserError()
        }
    }

    private func reverseParseIf(_ char: UInt8, _ buffer: inout ByteBuffer) throws -> Bool {
        switch buffer.readableBytesView.last {
        case .some(char):
            buffer.moveWriterIndex(to: buffer.writerIndex - 1)
            return true
        case .some(_):
            return false
        case .none:
            throw ParserError(hint: "whilst looking for \(char), found no bytes")
        }
    }

    private func reverseParseNumber(_ buffer: inout ByteBuffer) throws -> Int {
        var current = 0
        var magnitude = 1
        while true {
            switch buffer.readableBytesView.last {
            case .some(let digit) where (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains(digit):
                current += (magnitude * Int(digit - UInt8(ascii: "0")))
                magnitude *= 10
                buffer.moveWriterIndex(to: buffer.writerIndex - 1)
            case .some(_):
                if magnitude == 1 {
                    throw ParserError()
                } else {
                    return current
                }
            case .none:
                throw ParserError()
            }
        }
    }

    private func lineFragmentType(_ fragment: ByteBuffer) throws -> LineFragmentType {
        var fragment = fragment
        try reverseParseTrailingNewlines(&fragment)
        guard fragment.readableBytes > 0 else {
            return .completeLine // this is just an empty line
        }
        if try reverseParseIf(UInt8(ascii: "}"), &fragment) {
            if try reverseParseIf(UInt8(ascii: "+"), &fragment) || reverseParseIf(UInt8(ascii: "-"), &fragment) {
                let number = try reverseParseNumber(&fragment)
                return .nonSynchronisingLiteral(number)
            } else {
                let number = try reverseParseNumber(&fragment)
                return .synchronisingLiteral(number)
            }
        } else {
            return .completeLine
        }
    }

    private mutating func parseNewline(_ buffer: inout ByteBuffer) throws -> Bool {
        switch (buffer.readableBytesView.first, buffer.readableBytesView.dropFirst().first) {
        case (.some(UInt8(ascii: "\n")), _):
            buffer.moveReaderIndex(forwardBy: 1)
            return true
        case (.some(UInt8(ascii: "\r")), .none):
            buffer.moveReaderIndex(forwardBy: 1)
            return false
        case (.some(UInt8(ascii: "\r")), .some(UInt8(ascii: "\n"))):
            buffer.moveReaderIndex(forwardBy: 2)
            return true
        case (.some(let char), _):
            throw ParserError(hint: "found character \(char) when expecting newline")
        case (.none, _):
            return false
        }
    }

    internal mutating func parse(_ buffer: inout ByteBuffer) throws -> ParseResult {
        guard buffer.readableBytes > 0 else {
            return ParseResult(line: nil, numberOfContinuationRequestsToSend: 0)
        }

        switch self.state {
        case .waitingForWholeLine:
            return try self.parseLine(&buffer)
        case .waitingForBytes(let numberOfBytesExpected):
            assert(self.accumulator == nil)
            if let parsed = buffer.readSlice(length: numberOfBytesExpected) {
                self.state = .waitingForWholeLine
                return ParseResult(line: parsed, numberOfContinuationRequestsToSend: 0)
            } else {
                let outstanding = numberOfBytesExpected - buffer.readableBytes
                precondition(outstanding > 0, "we have enough bytes, yet the test above failed")
                self.state = .waitingForBytes(outstanding)
                let parsed = buffer.readSlice(length: buffer.readableBytes)!
                return ParseResult(line: parsed, numberOfContinuationRequestsToSend: 0)
            }
        }
    }

    private mutating func parseLine(_ buffer: inout ByteBuffer) throws -> ParseResult {
        var continuations = 0
        var bytesToConsiderThisTime = buffer.readableBytesView
        while let firstNL = bytesToConsiderThisTime.firstIndex(of: UInt8(ascii: "\n")) {
            var finishingSlice = buffer.readSlice(length: firstNL - bytesToConsiderThisTime.startIndex + 1)!
            self.accumulator.append(&finishingSlice)

            let allFragments = self.accumulator!

            assert((allFragments.readableBytesView.last ?? 0)  == UInt8(ascii: "\n"))
            let outstandingLiteralBytes: Int
            switch try lineFragmentType(allFragments) {
            case .completeLine:
                // .clear() would CoW, so let's move manually
                self.accumulator!.moveReaderIndex(to: 0)
                self.accumulator!.moveWriterIndex(to: 0)
                return .init(line: allFragments, numberOfContinuationRequestsToSend: continuations)
            case .synchronisingLiteral(let number):
                bytesToConsiderThisTime = bytesToConsiderThisTime[firstNL + 1 ..< buffer.readableBytesView.endIndex]
                continuations += 1
                outstandingLiteralBytes = number
            case .nonSynchronisingLiteral(let number):
                bytesToConsiderThisTime = bytesToConsiderThisTime[firstNL + 1 ..< buffer.readableBytesView.endIndex]
                outstandingLiteralBytes = number
            }
            if allFragments.readableBytes + outstandingLiteralBytes > self.bufferSizeLimit {
                // switching to streaming mode
                assert(outstandingLiteralBytes > 0)
                assert(self.state == .waitingForWholeLine, "illegal state: \(self.state)")
                self.state = .waitingForBytes(outstandingLiteralBytes)
                self.accumulator = nil
                return .init(line: allFragments, numberOfContinuationRequestsToSend: continuations)
            }
        }

        self.accumulator.append(&buffer)
        guard self.accumulator!.readableBytes <= self.bufferSizeLimit else {
            throw NIOIMAP.ParsingError.lineTooLong
        }
        return .init(line: nil, numberOfContinuationRequestsToSend: continuations)
    }
}
