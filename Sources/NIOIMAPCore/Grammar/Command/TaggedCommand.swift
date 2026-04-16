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

/// A command tagged with an identifier for request/response correlation.
///
/// In the IMAP protocol (RFC 3501), clients send tagged commands to the server, and the
/// server includes the same tag in the response to correlate them. This struct combines
/// a unique tag (usually an alphanumeric string like "A001") with a ``Command``, allowing
/// the client to track which response corresponds to which request when multiple commands
/// are in flight (pipelining).
///
/// ### Example
///
/// ```
/// C: A001 LOGIN user@example.com password
/// S: A001 OK LOGIN completed
/// ```
///
/// The line `A001 LOGIN user@example.com password` is represented as a `TaggedCommand`
/// with `tag: "A001"` and `command: .login(...)`.
///
/// - SeeAlso: [RFC 3501 Section 2.2.1](https://datatracker.ietf.org/doc/html/rfc3501#section-2.2.1) (Command Syntax)
/// - SeeAlso: ``Command``, ``CommandStreamPart/tagged(_:)``
public struct TaggedCommand: Hashable, Sendable {
    /// The tag string used to correlate this command with its response.
    ///
    /// Tags are typically alphanumeric identifiers assigned by the client. The server
    /// will include this tag in its response to allow the client to match responses to
    /// requests, especially when using pipelined commands.
    public var tag: String

    /// The command to send with this tag.
    ///
    /// See ``Command`` for the full list of available commands.
    public var command: Command

    /// Creates a new tagged command.
    ///
    /// - parameter tag: The tag string, typically a mixture of alphanumeric characters
    /// - parameter command: The command to associate with the tag
    public init(tag: String, command: Command) {
        self.tag = tag
        self.command = command
    }
}

extension TaggedCommand: CustomDebugStringConvertible {
    public var debugDescription: String {
        CommandEncodeBuffer.makeDescription {
            $0.writeCommand(self)
        }
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
