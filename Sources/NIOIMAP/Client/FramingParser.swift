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

public struct InvalidFrame: Error, Hashable {
    public init() {}
}

public struct IntegerOverflow: Error, Hashable {
    public init() {}
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
        case normalTraversal(swallowLF: Bool)
        case foundCR
        case searchingForLiteralHeader(LiteralSubstate)
        case insideLiteral(remaining: Int)
    }

    var state: State = .normalTraversal(swallowLF: false)
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
        let buffer = self.buffer.readSlice(length: self.frameLength)
        self.frameLength = 0
        return buffer
    }

    private mutating func parseFrame() throws -> ByteBuffer? {
        while self.frameLength < self.buffer.readableBytes {
            switch self.state {
            case .normalTraversal(swallowLF: let swallowsLF):
                if self.readByte_state_normalTraversal(swallowLF: swallowsLF) {
                    return self.readFrame()
                }

            case .foundCR:
                let swallowLF = self.readByte_state_foundCR()
                self.state = .normalTraversal(swallowLF: swallowLF)
                return self.readFrame()

            case .searchingForLiteralHeader(let substate):
                if try self.readByte_state_searchingForLiteralHeader(substate: substate) {
                    return self.readFrame()
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
    private mutating func readByte_state_normalTraversal(swallowLF: Bool) -> Bool {
        let byte = self.readByte()
        switch byte {
        case CR:
            let swallowLF = self.readByte_state_foundCR()
            self.state = .normalTraversal(swallowLF: swallowLF)
            return true

        case LF:
            if swallowLF {
                // we want to completely remove the byte from the buffer
                _ = self.buffer.readBytes(length: 1)
            }
            return !swallowLF // if we are swallowing the line feed then we don't want a frame

        case LITERAL_HEADER_START:
            self.state = .searchingForLiteralHeader(.findingBinaryFlag)
            return false

        default:
            // We don't need to do anything this byte, as it's just a "normal" part of a
            // command. We "consume" it in the call to readByte above, which just makes
            // the current frame one byte longer.
            return false
        }
    }

    /// Returns `true` if the first LF should be consumed, otherwise false
    private mutating func readByte_state_foundCR() -> Bool {
        // We've found the end of a frame here.
        // If the next byte is an LF then we need to also consume
        // that, otherwise consider go back a byte and consider
        // that to be the end of the frame
        
        // If there's no next byte then assume we need to consume
        // whatever comes next. Note that this will only actually
        // be consumed if we find an LF.
        guard let byte = self.peekByte() else {
            return true
        }
        
        if byte == LF {
            self.frameLength += 1 // might as well read the byte if it's here
            self.state = .normalTraversal(swallowLF: false)
            return false
        } else {
            self.state = .normalTraversal(swallowLF: true)
            return true
        }
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader(substate: LiteralSubstate) throws -> Bool {
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

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingBinaryFlag() throws -> Bool {
        guard let binaryByte = self.peekByte() else {
            return false
        }
        if binaryByte == BINARY_FLAG {
            self.frameLength &+= 1
        }
        self.state = .searchingForLiteralHeader(.findingSize(ByteBuffer()))
        return try self.readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: ByteBuffer())
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_insideLiteral(remainingLiteralBytes: Int) {
        if self.buffer.readableBytes - self.frameLength >= remainingLiteralBytes {
            self.frameLength += remainingLiteralBytes
            self.state = .normalTraversal(swallowLF: false)
        } else {
            let readableLength = self.buffer.readableBytes - self.frameLength
            self.frameLength &+= readableLength
            self.state = .insideLiteral(remaining: remainingLiteralBytes - readableLength)
        }
    }

    private func parseIntegerFromBuffer(_ buffer: ByteBuffer) throws -> Int {
        guard let value = Int(String(buffer: buffer)) else {
            throw IntegerOverflow()
        }
        return value
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: ByteBuffer) throws -> Bool {
        var sizeBuffer = sizeBuffer

        // First scan for the end of the literal size
        while let byte = self.maybeReadByte() {
            switch byte {
            case UInt8(ascii: "0") ... UInt8(ascii: "9"):
                sizeBuffer.writeInteger(byte)
            case LITERAL_PLUS, LITERAL_MINUS:
                let size = try self.parseIntegerFromBuffer(sizeBuffer)
                self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
                return try self.readByte_state_searchingForLiteralHeader_findingClosingCurly(size)
            case LITERAL_HEADER_END:
                let size = try self.parseIntegerFromBuffer(sizeBuffer)
                self.state = .searchingForLiteralHeader(.findingCR(size))
                return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
            default:
                throw InvalidFrame()
            }
        }

        self.state = .searchingForLiteralHeader(.findingSize(sizeBuffer))
        return false
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingLiteralExtension(_ size: Int) throws -> Bool {
        // Now scan for the CRLF
        guard let byte = self.maybeReadByte() else {
            return false
        }

        switch byte {
        case LITERAL_PLUS, LITERAL_MINUS:
            self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
        case LITERAL_HEADER_END:
            self.frameLength -= 1
            self.state = .searchingForLiteralHeader(.findingCR(size))
        default:
            throw InvalidFrame()
        }

        self.state = .searchingForLiteralHeader(.findingCR(size))
        return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingClosingCurly(_ size: Int) throws -> Bool {
        guard let byte = self.maybeReadByte() else {
            return false
        }

        if byte == LITERAL_HEADER_END {
            self.state = .searchingForLiteralHeader(.findingCR(size))
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        } else {
            throw InvalidFrame()
        }
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingCR(_ size: Int) throws -> Bool {
        guard let byte = self.maybeReadByte() else {
            return false
        }

        if byte == CR {
            self.state = .searchingForLiteralHeader(.findingLF(size))
            return try self.readByte_state_searchingForLiteralHeader_findingLF(size)
        } else {
            throw InvalidFrame()
        }
    }

    /// Returns `true` if the frame is complete.
    private mutating func readByte_state_searchingForLiteralHeader_findingLF(_ size: Int) throws -> Bool {
        guard let byte = self.maybeReadByte() else {
            return false
        }

        if byte == LF {
            self.state = .insideLiteral(remaining: size)
            return true
        } else {
            throw InvalidFrame()
        }
    }
}
