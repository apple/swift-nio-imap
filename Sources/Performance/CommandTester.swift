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
import NIOIMAP

struct CommandTester {
    
    var iterations: Int
    var command: Command
    
    func run() {
        for i in 1...iterations {
            var commandBuffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .init())
            commandBuffer.writeCommand(.init(tag: "\(i)", command: command))
            
            var buffer = commandBuffer.buffer.nextChunk().bytes
            var parser = CommandParser(bufferLimit: 1000)
            _ = try! parser.parseCommandStream(buffer: &buffer)
        }
    }
    
}
