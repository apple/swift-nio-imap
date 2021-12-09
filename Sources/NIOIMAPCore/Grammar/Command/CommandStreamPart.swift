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

/// A special case of a normal `TaggedCommand`. Users may send large amounts of data
/// (e.g. an email with multiple attachments), and so this enum provides an easy way to send
/// or recieve parts of an email methodically. Multi-append is also supported by sending
/// multiple `beginMessage`.
public enum AppendCommand: Equatable {
    /// The beginning of an `AppendCommand`. There must be exactly one `start` for each `finish`.
    /// Always send this first before sending any other `AppendCommand`.
    /// - parameter tag: An identifier for the command, as in `TaggedCommand`
    /// - parameter appendingTo: The `MailboxName` destination.
    case start(tag: String, appendingTo: MailboxName)

    /// Provides metadata of a new message to append. There must be exactly one `beginMessage` for each `endMessage`.
    /// - parameter message: Metadata of the new message to append.
    case beginMessage(message: AppendMessage)

    /// Streams bytes belonging to the most recent `.beginMessage`. You may send an arbitrary number of
    /// `messageBytes` commands, however the total number of bytes sent must match exactly that specified in
    /// the corresponding `beginMessage`.
    /// - parameter ByteBuffer: The bytes to stream
    case messageBytes(ByteBuffer)

    /// Signals that sending the current message has finished. The command may now end
    /// by sending `.finish`, or start sending the next message.
    case endMessage

    /// Provides metadata to begin catenating. There must be exactly one `beginCatenate` for each `endCatenate`.
    /// - parameter options: The catenation metadata
    case beginCatenate(options: AppendOptions)

    /// Catenates a URL using the metadata given in the previous `beginCatenate` command.
    /// - parameter ByteBuffer: The URL to catenate as raw bytes.
    case catenateURL(ByteBuffer)

    /// Catenates data using the metadata given in the previous `beginCatenate` command.
    /// - parameter CatenateData: The data to catenate.
    case catenateData(CatenateData)

    /// Signals that there will be no more `catenateURL` or `catenateData` commands
    /// until another `beginCatenate` is sent.
    case endCatenate

    /// Signals that the append command has finished, and no more messages will be recieved
    /// without starting a new command.
    case finish

    public var tag: String? {
        switch self {
        case .start(let tag, _):
            return tag
        case .beginMessage, .messageBytes, .endMessage,
             .beginCatenate, .catenateURL, .catenateData,
             .endCatenate, .finish:
            return nil
        }
    }
}

extension AppendCommand {
    /// Use to manage the lifecycle of catenating data.
    /// One `begin(size:)` message must be sent before exactly one
    /// `end` message, with zero or more `bytes(ByteBuffer)` messages
    /// in the middle.
    public enum CatenateData: Equatable {
        /// Signals that a given number of bytes are ready to be sent.
        /// - parameter size: The number of bytes to be streamed
        case begin(size: Int)

        /// Sends zero or more bytes
        /// - parameter ByteBuffer: A `ByteBuffer` containing the data to send
        case bytes(ByteBuffer)

        /// Signals that no more data is to be sent as part of this catentation. To send more
        /// data you must send another `begin(size:)` message.
        case end
    }
}

/// Used by clients to stream commands to a server. Most commands are simple and sent under
/// the `.tagged(TaggedCommand)` case. Of note are `.idleDone` which will end an idle
/// session started by a previous idle `TaggedCommand`, and  `.append(AppendCommand)`
/// which is used to manage the lifecycle of appending multiple messages sequentially.
public enum CommandStreamPart: Equatable {
    /// Signals that a previous `idle` command has finished, and more
    /// commands will now be sent.
    case idleDone

    /// Sends a simple tagged command with the format `<tag> <command>\r\n`.
    /// - parameter TaggedCommand: The command to send.
    case tagged(TaggedCommand)

    /// Sends a sub-command that is used to append messages to a mailbox.
    /// - parameter AppendCommand: The sub-command to send.
    case append(AppendCommand)

    /// Sends some data in response to a continuation request
    case continuationResponse(ByteBuffer)

    /// The tag of the command. Only applies to `tagged` and `.append(.start)`.
    public var tag: String? {
        switch self {
        case .idleDone, .continuationResponse:
            return nil
        case .tagged(let taggedCommand):
            return taggedCommand.tag
        case .append(let appendCommand):
            return appendCommand.tag
        }
    }
}

extension CommandStreamPart: CustomDebugStringConvertible {
    public var debugDescription: String {
        var buffer = CommandEncodeBuffer(buffer: ByteBuffer(), options: .rfc3501)
        buffer.writeCommandStream(self)
        var chunk = buffer.buffer.nextChunk()
        var result = String(buffer: chunk.bytes)
        while chunk.waitForContinuation {
            chunk = buffer.buffer.nextChunk()
            result += String(buffer: chunk.bytes)
        }
        return result
    }
}

extension CommandEncodeBuffer {
    /// Writes a `CommandStreamPart` to the buffer ready to be sent to the network.
    /// - parameter stream: The `CommandStreamPart` to write.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeCommandStream(_ stream: CommandStreamPart) -> Int {
        switch stream {
        case .idleDone:
            return self.buffer.writeString("DONE\r\n")
        case .tagged(let command):
            return self.writeCommand(command)
        case .append(let command):
            return self.writeAppendCommand(command)
        case .continuationResponse(let bytes):
            return self.writeAuthenticationChallengeResponse(bytes)
        }
    }

    @discardableResult private mutating func writeBytes(_ bytes: ByteBuffer) -> Int {
        var buffer = bytes
        return self.buffer.writeBuffer(&buffer)
    }

    @discardableResult private mutating func writeAuthenticationChallengeResponse(_ bytes: ByteBuffer) -> Int {
        self.buffer.writeBufferAsBase64(bytes) + self.buffer.writeString("\r\n")
    }

    @discardableResult private mutating func writeAppendCommand(_ command: AppendCommand) -> Int {
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

            return self.buffer.write(if: self.encodedAtLeastOneCatenateElement) { self.buffer.writeSpace() } +
                self.buffer.writeString("URL ") +
                self.buffer.writeIMAPString(url)
        case .catenateData(.begin(let size)):
            var written = self.buffer.write(if: self.encodedAtLeastOneCatenateElement) { self.buffer.writeSpace() } +
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
