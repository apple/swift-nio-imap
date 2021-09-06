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

fileprivate let LITERAL_HEADER_START = UInt8(ascii: "{")
fileprivate let LITERAL_HEADER_END = UInt8(ascii: "}")
fileprivate let CR = UInt8(ascii: "\r")
fileprivate let LF = UInt8(ascii: "\n")
fileprivate let BINARY_FLAG = UInt8(ascii: "~")
fileprivate let LITERAL_PLUS = UInt8(ascii: "+")
fileprivate let LITERAL_MINUS = UInt8(ascii: "-")

public struct InvalidFrame: Error, Hashable {
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
        case normalTraversal
        case foundCR
        case foundLF
        case searchingForLiteralHeader(LiteralSubstate)
        case insideLiteral(remaining: Int)
    }

    var state: State = .normalTraversal
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
            case .normalTraversal:
                self.readByte_state_normalTraversal()

            case .foundCR:
                self.readByte_state_foundCR()
                self.state = .normalTraversal
                return readFrame()

            case .foundLF:
                self.state = .normalTraversal
                return readFrame()

            case .searchingForLiteralHeader(let substate):
                if try self.readByte_state_searchingForLiteralHeader(substate: substate) {
                    return readFrame()
                }

            case .insideLiteral(remaining: let remaining):
                // always instantly forward any bytes within a literal
                self.readByte_state_insideLiteral(remainingLiteralBytes: remaining)
                return readFrame()
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

    private mutating func maybeReadByte<T: FixedWidthInteger>(as: T.Type) -> T? {
        guard let value = self.buffer.getInteger(at: self.buffer.readerIndex + self.frameLength, as: T.self) else {
            return nil
        }
        self.frameLength &+= T.bitWidth / 8
        return value
    }
}

extension FramingParser {
    private mutating func readByte_state_normalTraversal() {
        let byte = self.readByte()
        switch byte {
        case CR:
            self.state = .foundCR
        case LF:
            self.state = .foundLF
        case LITERAL_HEADER_START:
            self.state = .searchingForLiteralHeader(.findingBinaryFlag)
        default:
            break
        }
    }

    private mutating func readByte_state_foundCR() {
        // We've found the end of a frame here.
        // If the next byte is an LF then we need to also consume
        // that, otherwise consider go back a byte and consider
        // that to be the end of the frame
        let byte = self.readByte()
        if byte != LF {
            self.frameLength -= 1
        }
    }

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

    private mutating func readByte_state_searchingForLiteralHeader_findingBinaryFlag() throws -> Bool {
        guard let binaryByte = self.maybeReadByte(as: UInt8.self) else {
            return false
        }
        if binaryByte != BINARY_FLAG {
            self.frameLength -= 1
        }
        self.state = .searchingForLiteralHeader(.findingSize(ByteBuffer()))
        return try self.readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: ByteBuffer())
    }

    private mutating func readByte_state_insideLiteral(remainingLiteralBytes: Int) {
        if self.buffer.readableBytes - self.frameLength >= remainingLiteralBytes {
            self.frameLength += remainingLiteralBytes
            self.state = .normalTraversal
        } else {
            let readableLength = self.buffer.readableBytes - self.frameLength
            self.frameLength += readableLength
            self.state = .insideLiteral(remaining: remainingLiteralBytes - readableLength)
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingSize(sizeBuffer: ByteBuffer) throws -> Bool {
        var sizeBuffer = sizeBuffer

        // First scan for the end of the literal size
        while let byte = self.maybeReadByte(as: UInt8.self) {
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                sizeBuffer.writeInteger(byte)
            case LITERAL_PLUS, LITERAL_MINUS:
                let size = Int(sizeBuffer.readString(length: sizeBuffer.readableBytes)!)!
                self.state = .searchingForLiteralHeader(.findingClosingCurly(size))
                return try self.readByte_state_searchingForLiteralHeader_findingClosingCurly(size)
            case LITERAL_HEADER_END:
                let size = Int(sizeBuffer.readString(length: sizeBuffer.readableBytes)!)!
                self.state = .searchingForLiteralHeader(.findingCR(size))
                return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
            default:
                throw InvalidFrame()
            }
        }

        self.state = .searchingForLiteralHeader(.findingSize(sizeBuffer))
        return false
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingLiteralExtension(_ size: Int) throws -> Bool {
        // Now scan for the CRLF
        guard let byte = self.maybeReadByte(as: UInt8.self) else {
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

    private mutating func readByte_state_searchingForLiteralHeader_findingClosingCurly(_ size: Int) throws -> Bool {
        guard let byte = self.maybeReadByte(as: UInt8.self) else {
            return false
        }

        if byte == LITERAL_HEADER_END {
            self.state = .searchingForLiteralHeader(.findingCR(size))
            return try self.readByte_state_searchingForLiteralHeader_findingCR(size)
        } else {
            throw InvalidFrame()
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingCR(_ size: Int) throws -> Bool {
        guard let byte = self.maybeReadByte(as: UInt8.self) else {
            return false
        }

        if byte == CR {
            self.state = .searchingForLiteralHeader(.findingLF(size))
            return try self.readByte_state_searchingForLiteralHeader_findingLF(size)
        } else {
            throw InvalidFrame()
        }
    }

    private mutating func readByte_state_searchingForLiteralHeader_findingLF(_ size: Int) throws -> Bool {
        guard let byte = self.maybeReadByte(as: UInt8.self) else {
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
