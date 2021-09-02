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
        
    }
    
    var buffer = ByteBuffer()
    
    mutating func appendAndFrameBuffer(_ buffer: inout ByteBuffer) -> [ByteBuffer] {
        
        // fast paths should be fast
        guard buffer.readableBytes > 0 else {
            return []
        }
        
        self.buffer.writeBuffer(&buffer)
        return self.parseFrame()
    }
    
    private mutating func parseFrame() -> [ByteBuffer] {
        assert(self.buffer.readableBytes > 0)
        
        return []
    }
}
