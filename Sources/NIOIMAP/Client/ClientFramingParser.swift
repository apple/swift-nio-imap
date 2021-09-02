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
    
    enum State: Hashable {
        case normalTraversal
        case foundCR
        case foundLF
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
            break
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
    
}
