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

extension NIOIMAP {

    public enum CommandStream: Equatable {
        case idleDone
        case command(Command)
        case bytes(ByteBuffer)
    }

}

extension NIOIMAP.CommandStream {
    internal var isStreamingCommand: Bool {
        switch self {
        case .bytes, .idleDone:
            return false
        case .command(let command):
            return command.isStreamingCommand
        }
    }
}

extension ByteBuffer {

    @discardableResult public mutating func writeCommandStream(_ stream: NIOIMAP.CommandStream) -> Int {
        switch stream {
        case .idleDone:
            return self.writeString("DONE\r\n")
        case .command(let command):
            return self.writeCommand(command)
        case .bytes(let bytes):
            var copy = bytes
            return self.writeBuffer(&copy)
        }
    }

}
