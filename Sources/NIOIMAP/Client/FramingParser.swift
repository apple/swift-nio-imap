//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOIMAPCore

private let LITERAL_HEADER_START = UInt8(ascii: "{")
private let LITERAL_HEADER_END = UInt8(ascii: "}")
private let CR = UInt8(ascii: "\r")
private let LF = UInt8(ascii: "\n")
private let BINARY_FLAG = UInt8(ascii: "~")
private let LITERAL_PLUS = UInt8(ascii: "+")
private let LITERAL_MINUS = UInt8(ascii: "-")
private let DIGIT_0 = UInt8(ascii: "0")
private let DIGIT_9 = UInt8(ascii: "9")

/// The frame contained bytes that can never lead to a
/// valid command or response, and so can be safely
/// discarded without having to close the connection.
public struct InvalidFrame: Error, Hashable {
    public init() {}
}

/// An error occurred when attempting to parse the size
/// of a `literal`. The bytes in question are attached.
public struct LiteralSizeParsingError: Error, Hashable {
    /// The bytes that resulted in a parsing error.
    public var buffer: ByteBuffer

    /// Creates a new `LiteralSizeParsingError` with
    /// the bytes that failed to parse into a `UInt64`.
    /// - parameter buffer: The bytes that resulted in a parsing error
    public init(buffer: ByteBuffer) {
        self.buffer = buffer
    }
}

extension FixedWidthInteger {
    init?(buffer: ByteBuffer) {
        self.init(String(buffer: buffer))
    }

    static var maximumAllowedCharacters: Int {
        Int(floor(log10(Float64(Self.max)))) + 1
    }
}

public enum FramingResult: Hashable, CustomDebugStringConvertible {
    /// We've found a complete frame, and this is the result
    case complete(ByteBuffer)

    /// The frame isn't yet complete, and how many bytes
    /// are needed to complete the frame.
    case incomplete(Int)

    /// We're currently inside a literal, and have `remainingBytes` left
    /// to go.
    case insideLiteral(ByteBuffer, remainingBytes: UInt64)

    /// The frame was determined to be incorrect, and these are the bytes.
    case invalid(ByteBuffer)

    public var debugDescription: String {
        switch self {
        case .complete(let buffer):
            return "COMPLETE: \(String(buffer: buffer))"
        case .incomplete(let bytesNeeded):
            return "INCOMPLETE: \(bytesNeeded) bytes required)"
        case .insideLiteral(let bytes, remainingBytes: let remaining):
            return "INSIDE_LITERAL: \(String(buffer: bytes)) remaining: \(remaining)"
        case .invalid(let buffer):
            return "INVALID: \(String(buffer: buffer))"
        }
    }
}

/// How to handle a potential `\n` in a CRLF if you've found
/// the CR.
enum LineFeedByteStrategy: Hashable {
    /// There's not currently any line feed byte present,
    /// and we don't know what comes next. So mark the
    /// current frame as complete and just ignore the next
    /// byte if it's a `\n`.
    case ignoreFirst

    /// The byte is already present, we might as well
    /// include it in the current frame.
    case includeInFrame
}

/// `parsedCompleteFrame` means that `self.readFrame()` will produce
/// a full IMAP frame that can be sent for parsing.
enum FrameStatus: Hashable {
    /// A full IMAP frame has been found, call `self.readFrame()`
    /// to get it.
    case parsedCompleteFrame

    /// A complete frame has not yet been found.
    case continueParsing
}

public struct FramingParser: Hashable {
    enum LiteralHeaderState: Hashable {
        case findingBinaryFlag
        case findingSize(ByteBuffer)
        case findingLiteralExtension(UInt64)
        case findingClosingCurly(UInt64)
        case findingCR(UInt64)
    }

    enum State: Hashable {
        case normalTraversal(LineFeedByteStrategy)
        case foundCR
        case searchingForLiteralHeader(LiteralHeaderState)
        case insideLiteral(lineFeedStrategy: LineFeedByteStrategy, remaining: UInt64)
    }

    var state: State = .normalTraversal(.includeInFrame)
    var frameLength: Int = 0
    var buffer = ByteBuffer()
    var bufferSizeLimit: Int

    @_spi(NIOIMAPInternal) public init(bufferSizeLimit: Int = IMAPDefaults.lineLengthLimit) {
        self.bufferSizeLimit = bufferSizeLimit
    }

    /// Appends the given `ByteBuffer` to the parsing buffer, and parses as many frames as possible.
    /// Each frame should be fully parsable by the client or server parsers, meaning they shouldn't throw
    /// an `IncompleteError` message from any frame that this parser outputs.
    /// - parameter buffer: The `ByteBuffer` containing new bytes from the network, to be appended to the current buffer.
    /// - returns: An array of frames.
    /// - throws: `InvalidFrame` if a frame was found to be unparsable.
    /// - throws: `LiteralSizeParsingError` if when parsing a literal header we found an invalid size field.
    @_spi(NIOIMAPInternal) public mutating func appendAndFrameBuffer(_ buffer: inout ByteBuffer) throws -> [FramingResult] {
        // fast paths should be fast
        guard buffer.readableBytes > 0 else {
            return []
        }
        self.buffer.writeBuffer(&buffer)

        return try self.adjustBufferAndParseFrames()
    }

    @_spi(NIOIMAPInternal) public mutating func appendAndFrameBytes(_ bytes: UnsafeRawBufferPointer) throws -> [FramingResult] {
        // fast paths should be fast
        guard !bytes.isEmpty else {
            return []
        }

        self.buffer.writeBytes(bytes)

        return try self.adjustBufferAndParseFrames()
    }

    @_spi(NIOIMAPInternal) public var inputBufferByteCount: Int {
        self.buffer.readableBytes
    }

    private mutating func adjustBufferAndParseFrames() throws -> [FramingResult] {
        // Discard bytes when we've read over half the buffer and at least 1KB
        defer {
            if self.buffer.readerIndex > (self.buffer.writerIndex / 2), self.buffer.readerIndex > 1000 {
                self.buffer.discardReadBytes()
            }
        }

        let frames = self.parseFrames()
        if let lastFrame = frames.last, case .incomplete = lastFrame, self.buffer.readableBytes > self.bufferSizeLimit {
            throw ByteToMessageDecoderError.PayloadTooLargeError()
        }

        return frames
    }

    private mutating func parseFrames() -> [FramingResult] {
        assert(self.buffer.readableBytes > 0)

        var results: [FramingResult] = []
        while self.buffer.readableBytes > 0 {
            let frame = self.parseFrame()
            results.append(frame)
            switch frame {
            case .incomplete:
                // we need to stop at the first incomplete frame
                return results
            case .invalid, .complete, .insideLiteral:
                ()
            }
        }
        return results
    }

    private mutating func readFrame() -> ByteBuffer {
        assert(self.frameLength > 0)
        assert(self.buffer.readableBytes >= self.frameLength)
        let buffer = self.buffer.readSlice(length: self.frameLength)
        self.frameLength = 0
        return buffer!
    }

    private mutating func parseFrame() -> FramingResult {
        while self.frameLength < self.buffer.readableBytes {
            switch self.state {
            case .normalTraversal(let lineFeedStrategy):
                let status = self.readByte_state_normalTraversal(lineFeedStrategy: lineFeedStrategy)
                switch status {
                case .parsedCompleteFrame:
                    return .complete(self.readFrame())
                case .continueParsing:
                    continue
                }

            case .foundCR:
                self.readByte_state_foundCR()
                return .complete(self.readFrame())

            case .searchingForLiteralHeader(let substate):
                return self.parseFrame_searchingForLiteralHeader(substate: substate)

            case .insideLiteral(lineFeedStrategy: let lfs, remaining: let remaining):
                self.readByte_state_insideLiteral(lineFeedStrategy: lfs, remainingLiteralBytes: remaining)
                if self.frameLength > 0 {
                    let buffer = self.readFrame()
                    return .insideLiteral(buffer, remainingBytes: remaining - UInt64(buffer.readableBytes))
                } else {
                    return .incomplete(self.generateIncompleteFramingResult())
                }
            }
        }
        return .incomplete(self.generateIncompleteFramingResult())
    }

    private mutating func parseFrame_searchingForLiteralHeader(substate: LiteralHeaderState) -> FramingResult {
        do {
            let frameStatus = try self.readByte_state_searchingForLiteralHeader(substate: substate)
            switch frameStatus {
            case .parsedCompleteFrame:
                return .complete(self.readFrame())
            case .continueParsing:
                return .incomplete(self.generateIncompleteFramingResult())
            }
        } catch {
            self.state = .normalTraversal(.includeInFrame)
            return .invalid(self.readFrame())
        }
    }

    private func generateIncompleteFramingResult() -> Int {
        switch self.state {
        case .normalTraversal:
            return 2 // we need the CRLF (not strictly _need_ as we're lenient)
        case .foundCR:
            return 0
        case .searchingForLiteralHeader(let substate):
            switch substate {
            case .findingBinaryFlag:
                return 4 // <size(1 byte minimum)> + } + CRLF
            case .findingSize(let buffer):
                // if we have some size bytes already we don't strictly _need_ more
                return buffer.readableBytes > 0 ? 3 : 4
            case .findingLiteralExtension:
                return 3 // } + CRLF
            case .findingClosingCurly:
                return 3 // } + CRLF
            case .findingCR:
                return 2 // CRLF
            }
        case .insideLiteral:
            return 1 // always forward on bytes instantly
        }
    }

    private mutating func readByte() -> UInt8 {
        assert(self.buffer.readableBytes > 0)
        assert(self.frameLength < self.buffer.readableBytes)
        defer {
            self.frameLength &+= 1
        }
        return self.buffer.getInteger(at: self.buffer.readerIndex + self.frameLength)! // we've asserted this is ok
    }

    private mutating func maybeReadByte() -> UInt8? {
        guard let value = self.buffer.getInteger(at: self.buffer.readerIndex + self.frameLength, as: UInt8.self) else {
            return nil
        }
        self.frameLength &+= 1
        return value
    }

    // We've read a byte we don't care about (probably a LF), so
    // we need to decrement the frame length, and move the reader
    // index forward to ensure it's ignored.
    private mutating func stepBackAndIgnoreByte() {
        self.buffer.moveReaderIndex(forwardBy: 1)
        self.frameLength &-= 1
    }

    private mutating func peekByte() -> UInt8? {
        guard self.frameLength < self.buffer.readableBytes else {
            return nil
        }
        return self.buffer.getInteger(at: self.buffer.readerIndex + self.frameLength, as: UInt8.self)! // we've asserted this is ok
    }
}

extension FramingParser {
    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_normalTraversal(lineFeedStrategy: LineFeedByteStrategy) -> FrameStatus {
        let byte = self.readByte()
        switch byte {
        case CR:
            self.readByte_state_foundCR()
            return .parsedCompleteFrame

        case LF:
            switch lineFeedStrategy {
            case .ignoreFirst:
                precondition(self.frameLength == 1)
                self.stepBackAndIgnoreByte()
                self.state = .normalTraversal(.includeInFrame)
                return .continueParsing
            case .includeInFrame:
                // if we weren't meant to ignore the LF then it
                // must be the end of the current frame
                return .parsedCompleteFrame
            }

        case LITERAL_HEADER_START:
            self.state = .searchingForLiteralHeader(.findingBinaryFlag)
            return .continueParsing

        default:
            // We don't need to do anything this byte, as it's just a "normal" part of a
            // command. We "consume" it in the call to readByte above, which just makes
            // the current frame one byte longer.
            return .continueParsing
        }
    }

    private mutating func readByte_state_foundCR() {
        guard let byte = self.peekByte() else {
            // As we don't yet have the next byte we have to assume
            // if might be an LF, in which case we want to skip it.
            self.state = .normalTraversal(.ignoreFirst)
            return
        }

        // We read a byte and it was a line feed, we might as well
        // include it in the frame if it's already here.
        if byte == LF {
            self.frameLength &+= 1
            self.state = .normalTraversal(.includeInFrame)
        } else {
            // The next byte wasn't a line feed, so just default
            // back to including any line feed in the frame.
            self.state = .normalTraversal(.includeInFrame)
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader(substate: LiteralHeaderState) throws -> FrameStatus {
        // Note that to reach this point we must have already found a `{`.

        switch substate {
        case .findingBinaryFlag:
            return try self.readByte_state_searchingForLiteralHeader_findingBinaryFlag()
        case .findingSize(let byteBuffer):
            return try self.readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: byteBuffer)
        case .findingLiteralExtension(let size):
            return try self.readByte_state_searchingForLiteralHeader_findingLiteralExtension(size)
        case .findingClosingCurly(let size):
            return try self.readByte_state_searchingForLiteralHeader_findingClosingCurly(size)
        case .findingCR(let size):
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingBinaryFlag() throws -> FrameStatus {
        guard let binaryByte = self.peekByte() else {
            return .continueParsing
        }
        if binaryByte == BINARY_FLAG {
            self.frameLength &+= 1
        }
        let sizeBuffer = ByteBuffer()
        self.state = .searchingForLiteralHeader(.findingSize(sizeBuffer))
        return try self.readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: sizeBuffer)
    }

    private mutating func readByte_state_insideLiteral(lineFeedStrategy: LineFeedByteStrategy, remainingLiteralBytes: UInt64) {
        switch lineFeedStrategy {
        case .ignoreFirst:
            if let byte = self.peekByte(), byte == LF {
                self.buffer.moveReaderIndex(forwardBy: 1)
            }
        case .includeInFrame:
            break
        }

        let bytesAvailable = self.buffer.readableBytes - self.frameLength
        if bytesAvailable >= remainingLiteralBytes {
            self.frameLength &+= Int(remainingLiteralBytes)
            self.state = .normalTraversal(.includeInFrame)
        } else {
            self.frameLength &+= bytesAvailable
            self.state = .insideLiteral(lineFeedStrategy: .includeInFrame, remaining: remainingLiteralBytes - UInt64(bytesAvailable))
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: ByteBuffer) throws -> FrameStatus {
        var sizeBuffer = sizeBuffer

        // First scan for the end of the literal size
        while let byte = self.maybeReadByte() {
            switch byte {
            case DIGIT_0 ... DIGIT_9:
                sizeBuffer.writeInteger(byte)
                guard sizeBuffer.readableBytes <= UInt64.maximumAllowedCharacters else {
                    throw LiteralSizeParsingError(buffer: sizeBuffer)
                }
            case LITERAL_PLUS, LITERAL_MINUS:
                guard let size = UInt64(String(buffer: sizeBuffer)) else {
                    throw LiteralSizeParsingError(buffer: sizeBuffer)
                }
                self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
                return try self.readByte_state_searchingForLiteralHeader_findingClosingCurly(size)
            case LITERAL_HEADER_END:
                guard let size = UInt64(String(buffer: sizeBuffer)) else {
                    throw LiteralSizeParsingError(buffer: sizeBuffer)
                }
                self.state = .searchingForLiteralHeader(.findingCR(size))
                return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
            default:
                throw InvalidFrame()
            }
        }

        self.state = .searchingForLiteralHeader(.findingSize(sizeBuffer))
        return .continueParsing
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingLiteralExtension(_ size: UInt64) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .continueParsing
        }

        switch byte {
        case LITERAL_PLUS, LITERAL_MINUS:
            self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
            return .continueParsing
        case LITERAL_HEADER_END:
            self.state = .searchingForLiteralHeader(.findingCR(size))
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        default:
            throw InvalidFrame()
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingClosingCurly(_ size: UInt64) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .continueParsing
        }

        if byte == LITERAL_HEADER_END {
            self.state = .searchingForLiteralHeader(.findingCR(size))
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        } else {
            throw InvalidFrame()
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingCR(_ size: UInt64) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .continueParsing
        }

        switch byte {
        case CR:
            self.readByte_state_searchingForLiteralHeader_findingLF(size)
        case LF:
            self.state = .insideLiteral(lineFeedStrategy: .includeInFrame, remaining: size)
        default:
            throw InvalidFrame()
        }

        return .parsedCompleteFrame
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingLF(_ size: UInt64) {
        guard let byte = self.peekByte() else {
            self.state = .insideLiteral(lineFeedStrategy: .ignoreFirst, remaining: size)
            return
        }

        if byte == LF {
            self.frameLength &+= 1
        }
        self.state = .insideLiteral(lineFeedStrategy: .includeInFrame, remaining: size)
    }
}
