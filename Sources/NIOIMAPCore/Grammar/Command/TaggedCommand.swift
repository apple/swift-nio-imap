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

/// IMAP4 `command` (`command-any`, `command-auth`, `command-nonauth`, `command-select`)
public struct TaggedCommand: Equatable {
    public var tag: String
    public var command: Command

    public init(tag: String, command: Command) {
        self.tag = tag
        self.command = command
    }
}

extension CommandEncodeBuffer {
    @discardableResult public mutating func writeCommand(_ command: TaggedCommand) -> Int {
        var size = 0
        size += self.buffer.writeString("\(command.tag) ")
        size += self.writeCommand(command.command)
        size += self.buffer.writeString("\r\n")
        return size
    }
}
