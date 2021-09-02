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

struct ClientFramingParser: Hashable {
    
    enum LiteralSubstate: Hashable {
        case findingSize(ByteBuffer)
        case foundSize(Int)
        case foundCR(Int)
    }
    
    enum State: Hashable {
        case normalTraversal
        case foundCR
        case foundLF
        case searchingForLiteralHeader(LiteralSubstate)
        case insideLiteral(remainig: Int)
    }
    
    var state: State = .normalTraversal
    var frameLength: Int = 0
    var buffer = ByteBuffer()
    
    init() {
        
    }
    
    mutating func appendAndFrameBuffer(_ buffer: inout ByteBuffer) -> [ByteBuffer] {
        
        // fast paths should be fast
        guard buffer.readableBytes > 0 else {
            return []
        }
        
        self.buffer.writeBuffer(&buffer)
        return self.parseFrames()
    }
    
    private mutating func parseFrames() -> [ByteBuffer] {
        assert(self.buffer.readableBytes > 0)
        
        var results: [ByteBuffer] = []
        while let frame = self.parseFrame() {
            results.append(frame)
        }
        return results
    }
    
    private mutating func parseFrame() -> ByteBuffer? {
        var foundFrame = false
        while self.frameLength < self.buffer.readableBytes && !foundFrame {
            switch self.state {
                
            case .normalTraversal:
                self.readByte_state_normalTraversal()
                
            case .foundCR:
                self.readByte_state_foundCR()
                self.state = .normalTraversal
                foundFrame = true
                
            case .foundLF:
                self.state = .normalTraversal
                foundFrame = true
                
            case .searchingForLiteralHeader(let substate):
                foundFrame = self.readByte_state_searchingForLiteralHeader(substate: substate)
                
            case .insideLiteral(remainig: let remaining):
                // always instantly forward any bytes within a literal
                self.readByte_state_insideLiteral(remainingLiteralBytes: remaining)
                foundFrame = true
            }
        }
        
        if foundFrame {
            defer {
                self.frameLength = 0
            }
            return self.buffer.readSlice(length: self.frameLength)
        }
        
        return nil
    }
    
    private mutating func readByte() -> UInt8 {
        assert(self.buffer.readableBytes > 0)
        assert(self.frameLength < self.buffer.readableBytes)
        defer {
            self.frameLength += 1
        }
        return self.buffer.getInteger(at: self.buffer.readerIndex + self.frameLength)! // we've asserted this is ok
    }
    
    private mutating func maybeReadByte<T: FixedWidthInteger>(as: T.Type) -> T? {
        guard let value = self.buffer.getInteger(at: self.buffer.readerIndex + self.frameLength, as: T.self) else {
            return nil
        }
        self.frameLength += T.bitWidth / 8
        return value
    }
}

extension ClientFramingParser {
    
    private mutating func readByte_state_normalTraversal() {
        let byte = self.readByte()
        switch byte {
        case UInt8(ascii: "\r"):
            self.state = .foundCR
        case UInt8(ascii: "\n"):
            self.state = .foundLF
        case UInt8(ascii: "{"):
            self.state = .searchingForLiteralHeader(.findingSize(ByteBuffer()))
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
        if byte != UInt8(ascii: "\n") {
            self.frameLength -= 1
        }
    }
    
    private mutating func readByte_state_searchingForLiteralHeader(substate: LiteralSubstate) -> Bool {
        // Note that to reach this point we must have already found a `{`.
        
        switch substate {
        case .findingSize(let byteBuffer):
            return self.readByte_state_searchingForLiteralHeader_findSize(sizeBuffer: byteBuffer)
        case .foundSize(let size):
            return self.readByte_state_searchingForLiteralHeader_foundSize(size)
        case .foundCR(let size):
            return self.readByte_state_searchingForLiteralHeader_foundCR(size)
        }
    }
    
    private mutating func readByte_state_insideLiteral(remainingLiteralBytes: Int) {
        if self.buffer.readableBytes - self.frameLength >= remainingLiteralBytes {
            self.frameLength += remainingLiteralBytes
            self.state = .normalTraversal
        } else {
            let readableLength = self.buffer.readableBytes - self.frameLength
            self.frameLength += readableLength
            self.state = .insideLiteral(remainig: remainingLiteralBytes - readableLength)
        }
    }
    
    private mutating func readByte_state_searchingForLiteralHeader_findSize(sizeBuffer: ByteBuffer) -> Bool {
        var sizeBuffer = sizeBuffer
        // First scan for the end of the literal size
        var foundSize = false
        while self.frameLength < self.buffer.readableBytes && !foundSize {
            let byte = self.readByte()
            switch byte {
            case UInt8(ascii: "0"),
                UInt8(ascii: "1"),
                UInt8(ascii: "2"),
                UInt8(ascii: "3"),
                UInt8(ascii: "4"),
                UInt8(ascii: "5"),
                UInt8(ascii: "6"),
                UInt8(ascii: "7"),
                UInt8(ascii: "8"),
                UInt8(ascii: "9"):
                sizeBuffer.writeInteger(byte)
            case UInt8(ascii: "}"):
                foundSize = true
            default:
                fatalError("Handle this - the frame will never be valid")
            }
        }
        self.state = .searchingForLiteralHeader(.findingSize(sizeBuffer))
        
        // if we haven't found the size then we don't yet have a frame
        guard foundSize else {
            return false
        }
        
        // the loop above enforces a valid integer
        // parse the size, then try to parse the CRLF
        let size = Int(sizeBuffer.readString(length: sizeBuffer.readableBytes)!)!
        self.state = .searchingForLiteralHeader(.foundSize(size))
        return self.readByte_state_searchingForLiteralHeader_foundSize(size)
    }
    
    private mutating func readByte_state_searchingForLiteralHeader_foundSize(_ size: Int) -> Bool {
        
        // Now scan for the CRLF
        guard let byte = self.maybeReadByte(as: UInt8.self) else {
            return false
        }
        
        if byte == UInt8(ascii: "\r") {
            self.state = .searchingForLiteralHeader(.foundCR(size))
            return self.readByte_state_searchingForLiteralHeader_foundCR(size)
        } else {
            fatalError("Handle this - the frame will never be valid")
        }
    }
    
    private mutating func readByte_state_searchingForLiteralHeader_foundCR(_ size: Int) -> Bool {
        guard let byte = self.maybeReadByte(as: UInt8.self) else {
            return false
        }
        
        if byte == UInt8(ascii: "\n") {
            self.state = .insideLiteral(remainig: size)
            return true
        } else {
            fatalError("Handle this - the frame will never be valid")
        }
    }
}
