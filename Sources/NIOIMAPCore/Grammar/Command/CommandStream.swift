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
    case beginMessage(message: AppendMessage)
    case messageBytes(ByteBuffer)
    case endMessage
    case beginCatenate(options: AppendOptions)
    case catenateURL(ByteBuffer)
    case catenateData(CatenateData)
    case endCatenate
    case finish

    public enum CatenateData: Equatable {
        case begin(size: Int)
        case bytes(ByteBuffer)
        case end
    }
}

public enum CommandStream: Equatable {
    case idleDone
    case command(TaggedCommand)
    case append(AppendCommand)
}

extension CommandEncodeBuffer {
    @discardableResult public mutating func writeCommandStream(_ stream: CommandStream) -> Int {
        switch stream {
        case .idleDone:
            return self.buffer.writeString("DONE\r\n")
        case .command(let command):
            return self.writeCommand(command)
        case .append(let command):
            return self.writeAppendCommand(command)
        }
    }

    @discardableResult mutating func writeAppendCommand(_ command: AppendCommand) -> Int {
        switch command {
        case .start(tag: let tag, appendingTo: let mailbox):
            return
                self.buffer.writeString("\(tag) APPEND ") +
                self.buffer.writeMailbox(mailbox)
        case .beginMessage(message: let message):
            return self.buffer.writeAppendMessage(message)
        case .messageBytes(var bytes):
            return self.buffer.writeBuffer(&bytes)
        case .endMessage:
            return 0
        case .beginCatenate(options: let options):
            return self.buffer.writeAppendOptions(options) +
                self.buffer.writeString(" CATENATE (")
        case .catenateURL(let url):
            defer {
                self.encodedAtLeastOneCatenateElement = true
            }

            return self.buffer.writeIfTrue(self.encodedAtLeastOneCatenateElement) { self.buffer.writeSpace() } +
                self.buffer.writeString("URL ") +
                self.buffer.writeIMAPString(url)
        case .catenateData(.begin(let size)):
            var written = self.buffer.writeIfTrue(self.encodedAtLeastOneCatenateElement) { self.buffer.writeSpace() } +
                self.buffer.writeString("TEXT ")

            if self.options.useNonSynchronizingLiteralPlus {
                written += self.buffer.writeString("{\(size)+}\r\n")
            } else {
                written += self.buffer.writeString("{\(size)}\r\n")
                self.buffer.markStopPoint()
            }
            return written
        case .catenateData(.bytes(var bytes)):
            return self.buffer.writeBuffer(&bytes)
        case .catenateData(.end):
            self.encodedAtLeastOneCatenateElement = true
            return 0
        case .endCatenate:
            self.encodedAtLeastOneCatenateElement = false
            return self.buffer.writeString(")")
        case .finish:
            return self.buffer.writeString("\r\n")
        }
    }
}
