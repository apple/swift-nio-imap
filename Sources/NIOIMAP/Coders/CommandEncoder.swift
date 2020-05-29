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

    var capabilities: [Capability] = []

    public init() {}

    public func encode(data: CommandStream, out: inout ByteBuffer) throws {
        switch data {
        case .bytes(let buffer):
            out = buffer
        case .idleDone:
            out.writeString("DONE\r\n")
        case .command(let command):
            var encodeBuffer = EncodeBuffer(out, mode: .client, capabilities: self.capabilities)
            encodeBuffer.writeCommand(command)
            out = encodeBuffer.nextChunk().bytes
        }
    }
}
