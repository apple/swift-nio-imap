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

/// Represents a IMAP command that is preceded by a tag that can be used for command/response identification.
public struct TaggedCommand: Equatable {
    /// The tag, typically a mixture of alphanumeric characters.
    public var tag: String

    /// The command to associate with a tag.
    public var command: Command

    /// Creates a new `TaggedCommand`.
    /// - parameter tag: The tag, typically a mixture of alphanumeric characters.
    /// - parameter command: The command to associate with a tag.
    public init(tag: String, command: Command) {
        self.tag = tag
        self.command = command
    }
}

extension CommandEncodeBuffer {
    
    /// Writes a `TaggedCommand` to the buffer ready to be sent down the network.
    /// - parameter command: The `TaggedCommand` to write.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeCommand(_ command: TaggedCommand) -> Int {
        var size = 0
        size += self.buffer.writeString("\(command.tag) ")
        size += self.writeCommand(command.command)
        size += self.buffer.writeString("\r\n")
        return size
    }
}
