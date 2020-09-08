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

    public func encode(data: CommandRStream, out: inout ByteBuffer) throws {
        var encodeBuffer = CommandEncodeBuffer(buffer: out, capabilities: self.capabilities)
        encodeBuffer.writeCommandStream(data)
    }
}
