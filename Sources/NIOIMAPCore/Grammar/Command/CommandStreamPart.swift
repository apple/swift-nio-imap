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

/// A sub-command for streaming the `APPEND` command (RFC 3501 and RFC 4469 extensions).
///
/// The `AppendCommand` enum manages the lifecycle of appending messages to a mailbox. Unlike
/// simple tagged commands that send all data at once, `AppendCommand` breaks the operation
/// into discrete steps, allowing efficient streaming of large messages with multiple attachments
/// and support for the `CATENATE` extension (RFC 4469) to concatenate multiple parts.
///
/// **Multi-append support:** Multiple messages can be appended in a single command by sending
/// multiple `beginMessage`/`endMessage` pairs before `finish` (RFC 3502 MULTIAPPEND extension).
///
/// ### Example
///
/// ```
/// C: A001 APPEND INBOX (\Seen) "17-Jul-1996 09:01:33 -0700" {1234}
/// S: + Ready for literal data
/// C: <1234 bytes of message data>
/// S: * 10 EXISTS
/// S: A001 OK APPEND completed
/// ```
///
/// This wire format is managed through multiple `AppendCommand` values:
/// - `start(tag: "A001", appendingTo: "INBOX")` produces the command prefix
/// - `beginMessage(...)` produces the metadata (flags, date, size)
/// - `messageBytes(buffer)` streams the message data
/// - `endMessage` ends the current message
/// - `finish` completes the command with `\r\n`
///
/// The `CATENATE` extension (RFC 4469) allows combining multiple sources:
/// - `beginCatenate(options:)` starts a concatenation section
/// - `catenateURL(buffer)` references a message by URL
/// - `catenateData(.begin(size:))` starts inline data
/// - `catenateData(.bytes(buffer))` streams inline bytes
/// - `catenateData(.end)` ends inline data
/// - `endCatenate` completes the concatenation
///
/// - SeeAlso: [RFC 3501 Section 6.3.11](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.11)
/// - SeeAlso: [RFC 3502](https://datatracker.ietf.org/doc/html/rfc3502) (MULTIAPPEND Extension)
/// - SeeAlso: [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) (CATENATE Extension)
/// - SeeAlso: ``TaggedCommand``, ``AppendMessage``, ``AppendData``
public enum AppendCommand: Hashable, Sendable {
    /// The beginning of an `AppendCommand` sequence.
    ///
    /// There must be exactly one `start` for each `finish`. Always send this first before
    /// sending any other `AppendCommand` case in the sequence.
    ///
    /// - parameter tag: An identifier for the command, typically alphanumeric characters
    /// - parameter appendingTo: The destination mailbox name
    case start(tag: String, appendingTo: MailboxName)

    /// Metadata for a message to be appended to the mailbox.
    ///
    /// There must be exactly one `beginMessage` for each `endMessage`. This case encodes
    /// the message flags, internal date, and any extension fields. After this, stream
    /// the actual message bytes using `messageBytes(_:)`.
    ///
    /// - parameter message: Metadata of the new message to append, including flags and date
    case beginMessage(message: AppendMessage)

    /// Streams bytes of the current message being appended.
    ///
    /// You may send an arbitrary number of `messageBytes` commands; however, the total
    /// number of bytes sent must match exactly the byte count specified in the corresponding
    /// `beginMessage`.
    ///
    /// - parameter ByteBuffer: The bytes to stream
    case messageBytes(ByteBuffer)

    /// Signals that the current message has finished being streamed.
    ///
    /// The append command may now either:
    /// - Send `finish` to complete the entire append
    /// - Send another `beginMessage` to append an additional message (multi-append)
    case endMessage

    /// Begins a concatenation section using the `CATENATE` extension (RFC 4469).
    ///
    /// There must be exactly one `beginCatenate` for each `endCatenate`. After this,
    /// send zero or more `catenateURL` or `catenateData` commands to include parts
    /// from existing messages or inline data.
    ///
    /// - parameter options: The catenation metadata (flags, date, extensions)
    case beginCatenate(options: AppendOptions)

    /// Catenates a message part from a URL using the `CATENATE` extension (RFC 4469).
    ///
    /// The URL is included in the catenation and refers to an existing message or
    /// message part on the server.
    ///
    /// - parameter ByteBuffer: The URL to catenate as raw bytes
    case catenateURL(ByteBuffer)

    /// Catenates inline data using the `CATENATE` extension (RFC 4469).
    ///
    /// - parameter CatenateData: The data to catenate (begins size declaration, streams bytes, ends)
    case catenateData(CatenateData)

    /// Signals the end of a concatenation section using the `CATENATE` extension (RFC 4469).
    ///
    /// No more `catenateURL` or `catenateData` commands will be sent until another
    /// `beginCatenate` is sent (if concatenating multiple sections).
    case endCatenate

    /// Signals that the append command has finished.
    ///
    /// No more messages or catenation sections will be sent. This produces the final
    /// `\r\n` to complete the command.
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
    /// Management of inline data catenation using the `CATENATE` extension (RFC 4469).
    ///
    /// This enum manages the lifecycle of sending inline data as part of a catenation.
    /// One `begin(size:)` message must be sent before exactly one `end` message, with
    /// zero or more `bytes(_:)` messages in between.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 APPEND INBOX CATENATE (TEXT {100}
    /// S: + Ready for literal data
    /// C: <100 bytes of message data>
    /// C: URL "imap://server/INBOX/;uid=5/;section=1")
    /// S: * 11 EXISTS
    /// S: A001 OK APPEND completed
    /// ```
    ///
    /// The `{100}` declares the size and is represented as `CatenateData.begin(size: 100)`.
    /// The message bytes are streamed with `CatenateData.bytes(buffer)`, and completion
    /// is signaled with `CatenateData.end`.
    ///
    /// - SeeAlso: [RFC 4469 Section 4](https://datatracker.ietf.org/doc/html/rfc4469#section-4) (CATENATE Syntax)
    public enum CatenateData: Hashable, Sendable {
        /// Begins streaming inline data of a specific size.
        ///
        /// Declares the number of bytes to be streamed. The server responds with a continuation
        /// request (`+`) to indicate readiness for the literal data.
        ///
        /// - parameter size: The number of bytes to be streamed
        case begin(size: Int)

        /// Streams zero or more bytes of inline data.
        ///
        /// Multiple `bytes(_:)` cases can be sent to accumulate the declared size.
        ///
        /// - parameter ByteBuffer: A buffer containing the data to send
        case bytes(ByteBuffer)

        /// Signals the end of inline data streaming.
        ///
        /// No more data should be sent for this catenation part. To send additional data,
        /// send another `begin(size:)` case followed by more `bytes(_:)` cases.
        case end
    }
}

/// A part of a streaming command sent from a client to a server.
///
/// Clients use `CommandStreamPart` to send both simple tagged commands (``tagged(_:)``)
/// and complex multi-part operations like appending messages (``append(_:)``) and ending
/// IDLE sessions (``idleDone``). This enum provides a unified interface for managing
/// the client-server protocol state across different command types.
///
/// **Tagged Commands:** Most client commands are simple and sent as ``tagged(_:)`` with
/// all data at once. These correspond to protocol lines like:
/// ```
/// C: A001 LOGIN user password
/// C: A001 FETCH 1:* (BODY[1])
/// ```
///
/// **Streaming Commands:** The ``append(_:)`` case manages multi-step append operations,
/// allowing efficient streaming of large messages or catenation of multiple parts using
/// the RFC 4469 `CATENATE` extension.
///
/// **Continuation Responses:** The ``continuationResponse(_:)`` case sends client data
/// in response to a continuation request (`+`) from the server, such as when uploading
/// message data or providing authentication credentials.
///
/// **Terminating IDLE:** The ``idleDone`` case ends an active IDLE session (RFC 2177),
/// allowing the client to send regular commands again.
///
/// - SeeAlso: [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501) (IMAP Base Protocol)
/// - SeeAlso: [RFC 2177 Section 3](https://datatracker.ietf.org/doc/html/rfc2177#section-3) (IDLE Command)
/// - SeeAlso: [RFC 4469](https://datatracker.ietf.org/doc/html/rfc4469) (CATENATE Extension)
/// - SeeAlso: ``TaggedCommand``, ``AppendCommand``, ``Response``
public enum CommandStreamPart: Hashable, Sendable {
    /// Signals the end of an IDLE session using the `IDLE` extension (RFC 2177).
    ///
    /// Sends the literal string `DONE\r\n` to terminate a previous IDLE command and
    /// return the client to normal command-response mode.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 IDLE
    /// S: + idling
    /// (Server sends untagged updates as needed)
    /// C: DONE
    /// S: A001 OK IDLE terminated
    /// ```
    ///
    /// The `DONE` line is represented as the ``idleDone`` case.
    ///
    /// - SeeAlso: [RFC 2177 Section 3](https://datatracker.ietf.org/doc/html/rfc2177#section-3)
    /// - SeeAlso: ``Command/idleStart``
    case idleDone

    /// Sends a simple tagged command ready for transmission.
    ///
    /// Most client commands are tagged and sent as a single unit with all parameters.
    /// The ``tag`` property extracts the command tag for correlation with responses.
    ///
    /// - parameter TaggedCommand: The command to send
    case tagged(TaggedCommand)

    /// Sends a sub-command that is part of a multi-step append operation.
    ///
    /// The ``tag`` property extracts the tag from ``AppendCommand/start(tag:appendingTo:)``,
    /// if present.
    ///
    /// - parameter AppendCommand: The sub-command to send
    case append(AppendCommand)

    /// Sends data in response to a server continuation request (`+`).
    ///
    /// When a server sends a continuation request (e.g., during authentication or
    /// literal data upload), the client responds with this case. The buffer typically
    /// contains base64-encoded credentials for `AUTHENTICATE` commands or raw message
    /// bytes for message uploads.
    ///
    /// - parameter ByteBuffer: The response data as raw bytes
    case continuationResponse(ByteBuffer)

    /// The tag of the command, if any.
    ///
    /// Returns the command tag for ``tagged(_:)`` and ``append(_:)`` cases (specifically
    /// from ``AppendCommand/start(tag:appendingTo:)``), which matches the original
    /// command tag to correlate client requests with server responses. Returns `nil` for
    /// ``idleDone`` and ``continuationResponse(_:)`` cases, which are not tagged commands.
    ///
    /// - Returns: The tag string for tagged commands, or `nil` for untagged operations.
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
        CommandEncodeBuffer.makeDescription {
            $0.writeCommandStream(self)
        }
    }

    /// Creates a string from the array of `CommandStreamPart` with all _personally identifiable information_ redacted.
    public static func descriptionWithoutPII(_ parts: some Sequence<CommandStreamPart>) -> String {
        CommandEncodeBuffer.makeDescription(loggingMode: true) {
            for p in parts {
                $0.writeCommandStream(p)
            }
        }
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
                self.buffer.writeString("\(tag) APPEND ") + self.buffer.writeMailbox(mailbox)
        case .beginMessage(message: let message):
            return self.buffer.writeAppendMessage(message)
        case .messageBytes(var bytes):
            guard !self.buffer.loggingMode else { return 0 }
            return self.buffer.writeBuffer(&bytes)
        case .endMessage:
            guard !self.buffer.loggingMode else {
                return self.buffer.writeString("∅")
            }
            return 0
        case .beginCatenate(options: let options):
            return self.buffer.writeAppendOptions(options) + self.buffer.writeString(" CATENATE (")
        case .catenateURL(let url):
            defer {
                self.encodedAtLeastOneCatenateElement = true
            }

            return self.buffer.write(if: self.encodedAtLeastOneCatenateElement) { self.buffer.writeSpace() }
                + self.buffer.writeString("URL ") + self.buffer.writeIMAPString(url)
        case .catenateData(.begin(let size)):
            var written =
                self.buffer.write(if: self.encodedAtLeastOneCatenateElement) { self.buffer.writeSpace() }
                + self.buffer.writeString("TEXT ")

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
