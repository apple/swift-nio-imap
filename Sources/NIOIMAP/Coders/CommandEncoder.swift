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
import NIOIMAPCore

enum CommandEncodingError: Error, Equatable {
    case missingBytes
}

public class CommandEncoder: MessageToByteEncoder {
    public typealias OutboundIn = CommandStream

    enum Mode: Equatable {
        case normal
        case bytes(remaining: Int)
    }

    var capabilities: [Capability] = []
    private var mode = Mode.normal

    public init() {}

    public func encode(data: CommandStream, out: inout ByteBuffer) throws {
        switch data {
        case .idleDone:
            out.writeString("DONE\r\n")
        case .command(let command):
            var encodeBuffer = EncodeBuffer.clientEncodeBuffer(buffer: out, capabilities: self.capabilities)
            encodeBuffer.writeCommand(command)
            out = encodeBuffer.nextChunk().bytes
        case .append(let command):
            try self.encodeAppendCommand(command, into: &out)
        }
    }

    private func encodeAppendCommand(_ command: AppendCommand, into buffer: inout ByteBuffer) throws {
        switch command {
        case .start(tag: let tag, appendingTo: let mailbox):
            self.handleAppendStart(into: &buffer, tag: tag, mailbox: mailbox)
        case .beginMessage(messsage: let messsage):
            self.handleAppendBeginMessage(into: &buffer, message: messsage)
        case .messageBytes(let bytes):
            self.handleAppendBytes(into: &buffer, bytes: bytes)
        case .endMessage:
            try self.handleAppendEndMessage()
        case .finish:
            self.handleAppendMessageFinish(into: &buffer)
        }
    }

    private func handleAppendStart(into buffer: inout ByteBuffer, tag: String, mailbox: MailboxName) {
        precondition(self.mode == .normal)
        var encodeBuffer = EncodeBuffer.clientEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
        encodeBuffer.writeString("\(tag) APPEND ")
        encodeBuffer.writeMailbox(mailbox)
        buffer = encodeBuffer.nextChunk().bytes
    }

    private func handleAppendBeginMessage(into buffer: inout ByteBuffer, message: AppendMessage) {
        precondition(self.mode == .normal)
        var encodeBuffer = EncodeBuffer.clientEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
        encodeBuffer.writeAppendMessage(message)
        self.mode = .bytes(remaining: message.data.byteCount)
        buffer = encodeBuffer.nextChunk().bytes
    }

    private func handleAppendBytes(into buffer: inout ByteBuffer, bytes: ByteBuffer) {
        var encodeBuffer = EncodeBuffer.clientEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
        guard case .bytes = self.mode else {
            preconditionFailure("Incorrect mode")
        }
        var bytes = bytes
        encodeBuffer.writeBuffer(&bytes)
        buffer = encodeBuffer.nextChunk().bytes
    }

    private func handleAppendEndMessage() throws {
        guard case .bytes(let remaining) = self.mode else {
            preconditionFailure("Incorrect mode")
        }
        guard remaining == 0 else {
            throw CommandEncodingError.missingBytes
        }
        self.mode = .normal
    }

    private func handleAppendMessageFinish(into buffer: inout ByteBuffer) {
        var encodeBuffer = EncodeBuffer.clientEncodeBuffer(buffer: buffer, capabilities: self.capabilities)
        encodeBuffer.writeString("\r\n")
        buffer = encodeBuffer.nextChunk().bytes
    }
}
