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

private let LITERAL_HEADER_START = UInt8(ascii: "{")
private let LITERAL_HEADER_END = UInt8(ascii: "}")
private let CR = UInt8(ascii: "\r")
private let LF = UInt8(ascii: "\n")
private let BINARY_FLAG = UInt8(ascii: "~")
private let LITERAL_PLUS = UInt8(ascii: "+")
private let LITERAL_MINUS = UInt8(ascii: "-")
private let DIGIT_0 = UInt8(ascii: "0")
private let DIGIT_9 = UInt8(ascii: "9")

public struct InvalidFrame: Error, Hashable {
    public init() {}
}

public struct LiteralSizeParsingError: Error, Hashable {
    public var buffer: ByteBuffer
    public init(buffer: ByteBuffer) {
        self.buffer = buffer
    }
}

extension FixedWidthInteger {
    
    init?(buffer: ByteBuffer) {
        self.init(String(buffer: buffer))
    }
    
    static var maximumAllowedCharacters: Int {
        return Int(floor(log10(Float80(Self.max)))) + 1
    }
    
}

/// How to handle a potential `\n` in a CRLF if you've found
/// the CR.
enum LineFeedByteStrategy: Hashable {
    
    /// There's not currently any line feed byte present,
    /// and we don't know what comes next. So mark the
    /// current frame as complete and jsut ignore the next
    /// byte if it's a `\n`.
    case ignoreFirst
    
    /// The byte is already present, we might as well
    /// include it in the current frame.
    case includeInFrame
}

/// `complete` means that `self.readFrame()` will produce
/// a full IMAP frame that can be sent for parsing.
enum FrameStatus: Hashable {
    
    /// A full IMAP frame has been found, call `self.readFrame()`
    /// to get it.
    case complete
    
    /// A complete frame has not yet been found.
    case incomplete
}

struct FramingParser: Hashable {
    enum LiteralSubstate: Hashable {
        case findingBinaryFlag
        case findingSize(ByteBuffer)
        case findingLiteralExtension(Int)
        case findingClosingCurly(Int)
        case findingCR(Int)
        case findingLF(Int)
    }

    enum State: Hashable {
        case normalTraversal(LineFeedByteStrategy)
        case foundCR
        case searchingForLiteralHeader(LiteralSubstate)
        case insideLiteral(remaining: Int)
    }

    var state: State = .normalTraversal(.includeInFrame)
    var frameLength: Int = 0
    var buffer = ByteBuffer()

    init() {}

    mutating func appendAndFrameBuffer(_ buffer: inout ByteBuffer) throws -> [ByteBuffer] {
        // fast paths should be fast
        guard buffer.readableBytes > 0 else {
            return []
        }

        self.buffer.writeBuffer(&buffer)
        return try self.parseFrames()
    }
    
    private func _debugCurrentFrame() -> ByteBuffer {
        self.buffer.getSlice(at: self.buffer.readerIndex, length: self.frameLength)!
    }

    private mutating func parseFrames() throws -> [ByteBuffer] {
        assert(self.buffer.readableBytes > 0)

        var results: [ByteBuffer] = []
        while let frame = try self.parseFrame() {
            results.append(frame)
        }
        return results
    }

    private mutating func readFrame() -> ByteBuffer? {
        guard self.frameLength > 0 else {
            return nil
        }
        
        let buffer = self.buffer.readSlice(length: self.frameLength)
        self.frameLength = 0
        return buffer
    }

    private mutating func parseFrame() throws -> ByteBuffer? {
        while self.frameLength < self.buffer.readableBytes {
            switch self.state {
            case .normalTraversal(let lineFeedStrategy):
                let frameSatus = self.readByte_state_normalTraversal(lineFeedStrategy: lineFeedStrategy)
                switch frameSatus {
                case .complete:
                    return self.readFrame()
                case .incomplete:
                    break
                }

            case .foundCR:
                self.readByte_state_foundCR()
                return self.readFrame()

            case .searchingForLiteralHeader(let substate):
                let frameSatus = try self.readByte_state_searchingForLiteralHeader(substate: substate)
                switch frameSatus {
                case .complete:
                    return self.readFrame()
                case .incomplete:
                    break
                }

            case .insideLiteral(remaining: let remaining):
                // always instantly forward any bytes within a literal
                self.readByte_state_insideLiteral(remainingLiteralBytes: remaining)
                return self.readFrame()
            }
        }
        return nil
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
            return .complete

        case LF:
            switch lineFeedStrategy {
            case .ignoreFirst:
                precondition(self.frameLength == 1)
                // we now need to skip the LF without incrementing
                // the frame size
                self.buffer.moveReaderIndex(forwardBy: 1)
                self.frameLength &-= 1
                self.state = .normalTraversal(.includeInFrame)
            case .includeInFrame:
                // if we weren't meant to ignore the LF then it
                // must be the end of the current frame
                break
            }
            return .complete

        case LITERAL_HEADER_START:
            self.state = .searchingForLiteralHeader(.findingBinaryFlag)
            return .incomplete

        default:
            // We don't need to do anything this byte, as it's just a "normal" part of a
            // command. We "consume" it in the call to readByte above, which just makes
            // the current frame one byte longer.
            return .incomplete
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

    private mutating func readByte_state_searchingForLiteralHeader(substate: LiteralSubstate) throws -> FrameStatus {
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
        case .findingLF(let size):
            return try self.readByte_state_searchingForLiteralHeader_findingLF(size)
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingBinaryFlag() throws -> FrameStatus {
        guard let binaryByte = self.peekByte() else {
            return .incomplete
        }
        if binaryByte == BINARY_FLAG {
            self.frameLength &+= 1
        }
        self.state = .searchingForLiteralHeader(.findingSize(ByteBuffer()))
        return try self.readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: ByteBuffer())
    }

    private mutating func readByte_state_insideLiteral(remainingLiteralBytes: Int) {
        let bytesAvailable = self.buffer.readableBytes - self.frameLength
        if bytesAvailable >= remainingLiteralBytes {
            self.frameLength &+= remainingLiteralBytes
            self.state = .normalTraversal(.includeInFrame)
        } else {
            self.frameLength &+= bytesAvailable
            self.state = .insideLiteral(remaining: remainingLiteralBytes - bytesAvailable)
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
                    throw LiteralSizeParsingError(buffer: buffer)
                }
            case LITERAL_PLUS, LITERAL_MINUS:
                guard let size = Int(String(buffer: sizeBuffer)) else {
                    throw LiteralSizeParsingError(buffer: buffer)
                }
                self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
                return try self.readByte_state_searchingForLiteralHeader_findingClosingCurly(size)
            case LITERAL_HEADER_END:
                guard let size = Int(String(buffer: sizeBuffer)) else {
                    throw LiteralSizeParsingError(buffer: buffer)
                }
                self.state = .searchingForLiteralHeader(.findingCR(size))
                return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
            default:
                throw InvalidFrame()
            }
        }

        self.state = .searchingForLiteralHeader(.findingSize(sizeBuffer))
        return .incomplete
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingLiteralExtension(_ size: Int) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .incomplete
        }

        switch byte {
        case LITERAL_PLUS, LITERAL_MINUS:
            self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
            return .incomplete
        case LITERAL_HEADER_END:
            self.state = .searchingForLiteralHeader(.findingCR(size))
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        default:
            throw InvalidFrame()
        }
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingClosingCurly(_ size: Int) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .incomplete
        }

        if byte == LITERAL_HEADER_END {
            self.state = .searchingForLiteralHeader(.findingCR(size))
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        } else {
            throw InvalidFrame()
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingCR(_ size: Int) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .incomplete
        }

        if byte == CR {
            self.state = .searchingForLiteralHeader(.findingLF(size))
            return try self.readByte_state_searchingForLiteralHeader_findingLF(size)
        } else {
            throw InvalidFrame()
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingLF(_ size: Int) throws -> FrameStatus {
        guard let byte = self.maybeReadByte() else {
            return .incomplete
        }

        if byte == LF {
            self.state = .insideLiteral(remaining: size)
            return .complete
        } else {
            throw InvalidFrame()
        }
    }
}
