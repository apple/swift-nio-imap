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

public struct CommandEncoder: MessageToByteEncoder {
    public typealias OutboundIn = CommandStream

    var capabilities: EncodingCapabilities = []

    public init() {}

    public func encode(data: CommandStream, out: inout ByteBuffer) throws {
        switch data {
        case .idleDone:
            out.writeString("DONE\r\n")
        case .command(let command):
            var encodeBuffer = EncodeBuffer(out, mode: .client, capabilities: self.capabilities)
            try encodeBuffer.writeCommand(command)
            out = encodeBuffer.nextChunk().bytes
        case .append(let command):
            self.encodeAppendCommand(command, into: &out)
        }
    }
    
    func encodeAppendCommand(_ command: AppendCommand, into buffer: inout ByteBuffer) {
        var encodeBuffer = EncodeBuffer(buffer, mode: .client, capabilities: self.capabilities)
        switch command {
        case .start(tag: let tag, appendingTo: let mailbox):
            encodeBuffer.writeString("\(tag) APPEND ")
            encodeBuffer.writeMailbox(mailbox)
        case .beginMessage(messsage: let messsage):
            encodeBuffer.writeAppendMessage(messsage)
        case .messageBytes(var bytes):
            encodeBuffer.writeBuffer(&bytes)
        case .endMessage:
            break
        case .finish:
            encodeBuffer.writeString("\r\n")
        }
        buffer = encodeBuffer.nextChunk().bytes
    }
}
