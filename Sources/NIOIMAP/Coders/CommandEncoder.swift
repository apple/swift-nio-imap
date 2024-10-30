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
@_spi(NIOIMAPInternal) import NIOIMAPCore

enum CommandEncodingError: Error, Equatable {
    case missingBytes
}

class CommandEncoder: MessageToByteEncoder {
    typealias OutboundIn = CommandStreamPart

    enum Mode: Hashable {
        case normal
        case bytes(remaining: Int)
    }

    var loggingMode: Bool
    var capabilities: [Capability] = []
    private var mode = Mode.normal

    init(loggingMode: Bool) {
        self.loggingMode = loggingMode
    }

    func encode(data: CommandStreamPart, out: inout ByteBuffer) {
        var encodeBuffer = CommandEncodeBuffer(
            buffer: out,
            capabilities: self.capabilities,
            loggingMode: self.loggingMode
        )
        encodeBuffer.writeCommandStream(data)
        out = encodeBuffer.buffer.nextChunk().bytes
    }
}
