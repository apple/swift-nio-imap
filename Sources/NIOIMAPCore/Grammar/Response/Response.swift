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
import struct NIO.ByteBufferAllocator

public enum ResponseOrContinuationRequest: Hashable, Sendable {
    case continuationRequest(ContinuationRequest)
    case response(Response)
}

/// A response sent by a server.
///
/// Servers send responses in three forms to indicate status, convey data, or request a continuation:
/// untagged responses (prefixed with `*`), tagged responses (prefixed with a command tag),
/// and command continuation requests (prefixed with `+`). This enum wraps all response variants.
/// See [RFC 3501 Section 7](https://datatracker.ietf.org/doc/html/rfc3501#section-7) for details.
///
/// ## Response Types
///
/// **Untagged responses** (``untagged(_:)``) convey server data or status information that does not
/// indicate command completion. Examples include capabilities, mailbox status, and message data.
/// Multiple untagged responses may be sent for a single command.
///
/// **Tagged responses** (``tagged(_:)``) signal command completion with an OK, NO, or BAD status.
/// Exactly one tagged response is sent for each command, with a tag matching the original command.
///
/// **Special responses** handle authentication challenges (``authenticationChallenge(_:)``),
/// fatal server errors (``fatal(_:)``), and IDLE extension state (``idleStarted``).
/// ``fetch(_:)`` is specially handled to enable efficient streaming of large messages.
///
/// ### Example
///
/// ```
/// C: A001 CAPABILITY
/// S: * CAPABILITY IMAP4rev1 STARTTLS LOGIN
/// S: A001 OK CAPABILITY completed
/// ```
///
/// The line `* CAPABILITY IMAP4rev1 STARTTLS LOGIN` is wrapped as ``Response/untagged(_:)``
/// containing a ``ResponsePayload/capabilityData(_:)``. The line `A001 OK CAPABILITY completed`
/// is wrapped as ``Response/tagged(_:)`` with an `OK` status.
///
/// - SeeAlso: ``TaggedResponse``, ``ResponsePayload``, [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501)
public enum Response: Hashable, Sendable {
    /// An untagged response containing server data or status information.
    ///
    /// Untagged responses (prefixed with `*`) convey information about server capabilities, mailboxes,
    /// messages, or search results. Multiple untagged responses may be sent for a single command.
    /// See [RFC 3501 Section 7](https://datatracker.ietf.org/doc/html/rfc3501#section-7) for the
    /// complete list of untagged response types.
    ///
    /// ### Examples
    ///
    /// ```
    /// S: * FLAGS (\Answered \Flagged \Deleted \Seen \Draft)
    /// S: * 42 EXISTS
    /// S: * 0 RECENT
    /// ```
    ///
    /// These lines are each wrapped as ``Response/untagged(_:)`` containing
    /// ``ResponsePayload/mailboxData(_:)`` with various ``MailboxData`` cases:
    /// ``MailboxData/flags(_:)``,
    /// ``MailboxData/exists(_:)``, and ``MailboxData/recent(_:)``
    /// respectively.
    ///
    /// - SeeAlso: ``ResponsePayload``
    case untagged(ResponsePayload)

    /// A fetch response that may contain a large message body or attachments.
    ///
    /// Fetch responses are handled as a special case to enable efficient streaming of messages
    /// that may be too large to load entirely into memory. Each fetch response is broken into
    /// smaller parts (metadata, streaming chunks, completion markers) that can be processed
    /// incrementally.
    ///
    /// See [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    /// for the FETCH command specification.
    ///
    /// - SeeAlso: ``FetchResponse``
    case fetch(FetchResponse)

    /// A tagged response indicating command completion.
    ///
    /// Tagged responses (prefixed with a command tag) signal that the server has finished
    /// processing a command. Exactly one tagged response is sent for each command, with a tag
    /// matching the original command tag. The response contains a status code (`OK`, `NO`, or `BAD`)
    /// and optional human-readable text.
    ///
    /// ### Examples
    ///
    /// ```
    /// S: A001 OK CAPABILITY completed
    /// S: A002 NO [CANNOT] Mailbox does not exist
    /// ```
    ///
    /// Each of these lines is wrapped as ``Response/tagged(_:)`` with a ``TaggedResponse``
    /// containing the tag (`A001`, `A002`) and the outcome state (`OK` or `NO`).
    ///
    /// - SeeAlso: ``TaggedResponse``, [RFC 3501 Section 7.1](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1)
    case tagged(TaggedResponse)

    /// A fatal response indicating an unrecoverable error.
    ///
    /// Fatal responses (typically `BYE`) indicate that the server has encountered an unrecoverable
    /// error and is terminating the connection. After a fatal response, the client should close
    /// the connection and may reconnect if desired.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * BYE Server shutting down
    /// ```
    ///
    /// This line is wrapped as ``Response/fatal(_:)`` containing a ``ResponseText`` with the
    /// server's message.
    ///
    /// - SeeAlso: ``ResponseText``, [RFC 3501 Section 7.1.3](https://datatracker.ietf.org/doc/html/rfc3501#section-7.1.3)
    case fatal(ResponseText)

    /// Base64-encoded bytes sent by the server as an authentication challenge.
    ///
    /// During SASL authentication (see [RFC 4959](https://datatracker.ietf.org/doc/html/rfc4959)),
    /// the server sends authentication challenges prefixed with `+`. These bytes are typically
    /// base64-encoded and must be decoded by the client. The client responds with its own
    /// base64-encoded response.
    ///
    /// ### Example
    ///
    /// ```
    /// C: A001 AUTHENTICATE PLAIN
    /// S: +
    /// C: dXNlcm5hbWU6dXNlcm5hbWU6cGFzc3dvcmQ=
    /// S: A001 OK AUTHENTICATE completed
    /// ```
    ///
    /// The line `S: +` is the ``Response/authenticationChallenge(_:)`` case. The subsequent
    /// base64-encoded line `dXNlcm5hbWU6dXNlcm5hbWU6cGFzc3dvcmQ=` is the client's response to
    /// that challenge (not a separate response type).
    ///
    /// - SeeAlso: [RFC 4959](https://datatracker.ietf.org/doc/html/rfc4959) - IMAP Extension for SASL Initial Client Response
    case authenticationChallenge(ByteBuffer)

    /// Signals that the IDLE command has been successfully started.
    ///
    /// The IDLE extension (see [RFC 2177](https://datatracker.ietf.org/doc/html/rfc2177)) allows
    /// clients to request that the server send updates immediately when changes occur, rather than
    /// waiting for the client to poll. This case indicates that the server has accepted the IDLE
    /// command and is ready to push updates.
    ///
    /// Example:
    /// ```
    /// C: A001 IDLE
    /// S: + idling
    /// S: * 3 EXISTS
    /// ```
    ///
    /// - SeeAlso: [RFC 2177](https://datatracker.ietf.org/doc/html/rfc2177) - IMAP4 IDLE Extension
    case idleStarted

    /// The command tag associated with this response, if any.
    ///
    /// Returns the tag string for ``tagged(_:)`` responses, which matches the original command tag
    /// to correlate the response with its request. Returns `nil` for untagged responses, fatal responses,
    /// continuation requests, and other response types that are not associated with a specific command.
    ///
    /// - Returns: The tag string for tagged responses, or `nil` otherwise.
    public var tag: String? {
        switch self {
        case .untagged, .fetch, .fatal, .authenticationChallenge, .idleStarted:
            return nil
        case .tagged(let taggedResponse):
            return taggedResponse.tag
        }
    }
}

extension Response: CustomDebugStringConvertible {
    public var debugDescription: String {
        ResponseEncodeBuffer.makeDescription(loggingMode: false) {
            $0.writeResponse(self)
        }
    }

    /// Creates a string from the array of `Response` with all _personally identifiable information_ redacted.
    ///
    /// This is equivalent to joining `debugDescription` of all elements.
    public static func descriptionWithoutPII(_ responses: some Sequence<Response>) -> String {
        ResponseEncodeBuffer.makeDescription(loggingMode: true) {
            for response in responses {
                $0.writeResponse(response)
            }
        }
    }
}

/// A streaming response to a FETCH command.
///
/// The FETCH command (see [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5))
/// retrieves message attributes, structures, and content. To efficiently handle large messages with
/// attachments, fetch responses are broken into multiple parts that can be processed incrementally:
/// a start marker, metadata, optional streaming chunks, and a completion marker.
///
/// Clients can construct a complete message by processing events in this order:
/// 1. Receive ``start(_:)`` or ``startUID(_:)`` - marks the beginning of a fetch for a message
/// 2. Receive zero or more ``simpleAttribute(_:)`` - small metadata like FLAGS or ENVELOPE
/// 3. Receive zero or more streaming sections: ``streamingBegin(kind:byteCount:)`` followed by
///    multiple ``streamingBytes(_:)`` followed by ``streamingEnd`` - large content streamed in chunks
/// 4. Receive ``finish`` - marks the end of this fetch
///
/// ### Example
///
/// ```
/// S: * 1 FETCH (UID 123 FLAGS (\Seen))
/// S: * 1 FETCH (BODY[TEXT] {5432}
/// ... 5432 bytes of message body ...
/// S: )
/// ```
///
/// This represents a fetch for message 1. The first line contains the simple attributes
/// (UID and FLAGS), wrapped in separate ``FetchResponse/simpleAttribute(_:)`` events. The
/// second part begins a streaming section with ``FetchResponse/streamingBegin(kind:byteCount:)``
/// for the message body, followed by ``FetchResponse/streamingBytes(_:)`` events, and
/// concludes with ``FetchResponse/streamingEnd`` and ``FetchResponse/finish``.
///
/// - SeeAlso: ``StreamingKind``, ``MessageAttribute``, [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
public enum FetchResponse: Hashable, Sendable {
    /// The beginning of a fetch response for the message at the given sequence number.
    ///
    /// This is the first event in a fetch response sequence. The sequence number can be used to
    /// correlate this fetch with the original FETCH command.
    ///
    /// - SeeAlso: ``SequenceNumber``, [RFC 3501 Section 2.3.1.2](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3.1.2)
    case start(SequenceNumber)

    /// The beginning of a fetch response using the RFC 9586 “UID Only” mode.
    ///
    /// When a client uses “UID Only” mode (see [RFC 9586](https://datatracker.ietf.org/doc/html/rfc9586)),
    /// the server returns only the UID in the FETCH response rather than the sequence number.
    /// This is more efficient for pipelined commands.
    ///
    /// - SeeAlso: ``UID``, [RFC 9586](https://datatracker.ietf.org/doc/html/rfc9586) - IMAP Extension: SUBMIT
    case startUID(UID)

    /// A simple message attribute that fits entirely in a single message.
    ///
    /// Simple attributes are small enough to send without streaming. Examples include FLAGS,
    /// ENVELOPE, and BODYSTRUCTURE. These are processed immediately without waiting for additional
    /// data chunks.
    ///
    /// - SeeAlso: ``MessageAttribute``
    case simpleAttribute(MessageAttribute)

    /// The start of a streaming section containing potentially large data.
    ///
    /// This event indicates that a large message part (body, RFC 822 header, etc.) is about to be
    /// streamed to the client. The ``StreamingKind`` specifies which part is being streamed,
    /// and the `byteCount` parameter indicates the total bytes that will follow.
    ///
    /// After this event, expect one or more ``streamingBytes(_:)`` events containing the data,
    /// followed by a ``streamingEnd`` event.
    ///
    /// - parameter kind: The type and section of data being streamed
    /// - parameter byteCount: The total number of bytes that will be sent in this stream
    ///
    /// - SeeAlso: ``StreamingKind``, ``streamingBytes(_:)``, ``streamingEnd``, [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    case streamingBegin(kind: StreamingKind, byteCount: Int)

    /// A chunk of bytes from the currently streaming section.
    ///
    /// Multiple ``streamingBytes(_:)`` events may be sent for a single streaming section. The total
    /// bytes from all events for one section should equal the `byteCount` specified in the
    /// preceding ``streamingBegin(kind:byteCount:)`` event.
    ///
    /// - SeeAlso: ``streamingBegin(kind:byteCount:)``
    case streamingBytes(ByteBuffer)

    /// The end of the currently streaming section.
    ///
    /// This marks the completion of a streaming section started by ``streamingBegin(kind:byteCount:)``.
    /// More streaming sections may immediately follow, or the fetch may complete with ``finish``.
    ///
    /// - SeeAlso: ``streamingBegin(kind:byteCount:)``
    case streamingEnd

    /// The end of all fetch data for this message.
    ///
    /// This is the final event in a fetch response sequence. After this, processing of the message
    /// is complete, and a new fetch (or other response) may begin.
    case finish
}

/// The type of data in a streaming fetch response.
///
/// When a FETCH response includes large message content (body parts, headers, full messages),
/// the data is streamed to the client in chunks. This enum specifies which part of the message
/// is being streamed and how to interpret it.
///
/// See [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5) for
/// details on FETCH response formats.
public enum StreamingKind: Hashable, Sendable {
    /// A binary body part being streamed.
    ///
    /// The BINARY extension (see [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516)) allows
    /// fetching message parts as raw binary data without MIME encoding. The `section` identifies
    /// which part of the message is being streamed, and `offset` specifies a byte offset for
    /// partial fetches (when the PARTIAL extension is used).
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (BINARY[1] {512}
    /// ... 512 bytes of binary data ...
    /// S: )
    /// ```
    ///
    /// The `BINARY[1] {512}` indicates that 512 bytes of binary data from message part 1 will be
    /// streamed. This corresponds to ``StreamingKind/binary(section:offset:)`` with an empty offset.
    ///
    /// - parameter section: The part of the message to fetch (e.g., 1, 2.1)
    /// - parameter offset: Optional byte offset for partial fetch (requires RFC 9394 PARTIAL extension)
    ///
    /// - SeeAlso: ``SectionSpecifier/Part``, [RFC 3516](https://datatracker.ietf.org/doc/html/rfc3516)
    case binary(section: SectionSpecifier.Part, offset: Int?)

    /// A body section being streamed.
    ///
    /// The `BODY` fetch item returns message structure and content according to [RFC 3501](https://datatracker.ietf.org/doc/html/rfc3501).
    /// The `section` specifies which part of the message is being returned (e.g., TEXT for the message body,
    /// HEADER for headers, or 1.2.3 for nested MIME parts). The `offset` specifies a byte offset for
    /// partial fetches.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (BODY[TEXT] {1024}
    /// ... 1024 bytes of message body ...
    /// S: )
    /// ```
    ///
    /// The `BODY[TEXT] {1024}` indicates that 1024 bytes of the message body text will be streamed.
    /// This corresponds to ``StreamingKind/body(section:offset:)`` with the TEXT section specifier.
    ///
    /// - parameter section: The section specifier (part and section type)
    /// - parameter offset: Optional byte offset for partial fetch (requires RFC 9394 PARTIAL extension)
    ///
    /// - SeeAlso: ``SectionSpecifier``, [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    case body(section: SectionSpecifier, offset: Int?)

    /// The entire message including headers and body.
    ///
    /// RFC 822 format (equivalent to BODY[]) returns the complete message as stored on the server.
    /// See [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5) for details.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (RFC822 {2048}
    /// ... 2048 bytes of complete message ...
    /// S: )
    /// ```
    ///
    /// The `RFC822 {2048}` indicates that 2048 bytes of the complete message will be streamed.
    /// This corresponds to ``StreamingKind/rfc822``.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    case rfc822

    /// The message body without headers.
    ///
    /// RFC 822.TEXT (equivalent to BODY[TEXT]) returns only the message body portion,
    /// excluding all headers.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (RFC822.TEXT {1024}
    /// ... 1024 bytes of message body ...
    /// S: )
    /// ```
    ///
    /// The `RFC822.TEXT {1024}` indicates that 1024 bytes of the message body will be streamed.
    /// This corresponds to ``StreamingKind/rfc822Text``.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    case rfc822Text

    /// The message headers without body.
    ///
    /// RFC 822.HEADER (equivalent to BODY[HEADER]) returns only the message headers,
    /// excluding the message body.
    ///
    /// ### Example
    ///
    /// ```
    /// S: * 1 FETCH (RFC822.HEADER {512}
    /// ... 512 bytes of message headers ...
    /// S: )
    /// ```
    ///
    /// The `RFC822.HEADER {512}` indicates that 512 bytes of the message headers will be streamed.
    /// This corresponds to ``StreamingKind/rfc822Header``.
    ///
    /// - SeeAlso: [RFC 3501 Section 6.4.5](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.5)
    case rfc822Header
}

extension StreamingKind {
    public var sectionSpecifier: SectionSpecifier {
        switch self {
        case .binary(section: let section, offset: _):
            return SectionSpecifier(part: section, kind: .text)
        case .body(section: let section, offset: _):
            return section
        case .rfc822:
            return SectionSpecifier()
        case .rfc822Text:
            return SectionSpecifier(part: [], kind: .text)
        case .rfc822Header:
            return SectionSpecifier(part: [], kind: .header)
        }
    }

    public var offset: Int? {
        switch self {
        case .binary(section: _, offset: let offset):
            return offset
        case .body(section: _, offset: let offset):
            return offset
        case .rfc822:
            return nil
        case .rfc822Text:
            return nil
        case .rfc822Header:
            return nil
        }
    }
}

extension StreamingKind: CustomDebugStringConvertible {
    public var debugDescription: String {
        EncodeBuffer.makeDescription {
            $0.writeStreamingKind(self)
        }
    }
}
