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

import struct NIO.ByteBuffer

public enum AppendCommand: Equatable {
    case start(tag: String, appendingTo: MailboxName)
    case beginMessage(messsage: AppendMessage)
    case messageBytes(ByteBuffer)
    case endMessage
    case finish
}

public enum CommandStream: Equatable {
    case idleDone
    case command(TaggedCommand)
    case append(AppendCommand)
    case bytes(ByteBuffer)
}

extension CommandEncodeBuffer {
    @discardableResult public mutating func writeCommandStream(_ stream: CommandStream) throws -> Int {
        switch stream {
        case .idleDone:
            return self.buffer.writeString("DONE\r\n")
        case .command(let command):
            return try self.buffer.writeCommand(command)
        case .bytes(let bytes):
            var copy = bytes
            return self.buffer.writeBuffer(&copy)
        case .append(let command):
            return try self.writeAppendCommand(command)
        }
    }
    
    @discardableResult mutating func writeAppendCommand(_ command: AppendCommand) throws -> Int {
        switch command {
        case .start(tag: let tag, appendingTo: let mailbox):
            return
                self.buffer.writeString("\(tag) APPEND ") +
                self.buffer.writeMailbox(mailbox)
        case .beginMessage(messsage: let messsage):
            return self.buffer.writeAppendMessage(messsage)
        case .messageBytes(var bytes):
            return self.buffer.writeBuffer(&bytes)
        case .endMessage:
            return 0
        case .finish:
            return self.buffer.writeString("\r\n")
        }
    }
}
