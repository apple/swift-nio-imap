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

public enum ResponseOrContinuationRequest: Hashable {
    case continuationRequest(ContinuationRequest)
    case response(Response)
}

/// Wraps the various response types that may be sent by a server.
public enum Response: Hashable {
    /// Servers may send one or more untagged response for every tagged response.
    /// Untagged responses are sent before their corresponding tagged response.
    case untagged(ResponsePayload)

    /// `FetchResponse` are handled as a special case to enable streaming of large messages, e.g.
    /// those that contain attachments.
    case fetch(FetchResponse)

    /// Exactly one `TaggedResponse` is returned for each command, and is the last piece of data
    /// to be sent. Upon receiving a `TaggedResponse` the client knows that the server has finished
    /// processing the command specified by the tag.
    case tagged(TaggedResponse)

    /// Fatal responses indicate some unrecoverable error has occurred, and
    /// the server is now going to terminate the connection.
    case fatal(ResponseText)

    /// Bytes that will be base-64 encoded and sent to the client
    /// as part of the authentication flow. The client will send the necessary
    /// bytes in response to the challenge.
    case authenticationChallenge(ByteBuffer)

    /// Idle has started
    case idleStarted

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

/// The first event will always be `start`
/// The last event will always be `finish`
/// Every `start` has exactly one corresponding `finish`
/// After recieving `start` you may recieve n `simpleAttribute`, `streamingBegin`, and `streamingBytes` events.
/// Every `streamingBegin` has exaclty one corresponding `streamingEnd`
/// `streamingBegin` has a `type` that specifies the type of data to be streamed
public enum FetchResponse: Hashable {
    /// A fetch response is beginning for the message with the given sequence number.
    case start(SequenceNumber)

    /// A basic attribute that is small enough to be sent as one chunk, for example flags or an envelope.
    case simpleAttribute(MessageAttribute)

    /// Signals that streaming a potentially large amount of data is about to begin. Clients
    /// are notified of the type of stream, and how many bytes are to be expected.
    case streamingBegin(kind: StreamingKind, byteCount: Int)

    /// Bytes have been received.
    case streamingBytes(ByteBuffer)

    /// No more bytes will be received in this streaming session, however the server may immediately send
    /// another `.streamingBegin` message.
    case streamingEnd

    /// No more data will be sent for this message.
    case finish
}

/// The current type of data that is being streamed.
public enum StreamingKind: Hashable {
    /// BINARY RFC 3516, streams BINARY when using a `literal`
    case binary(section: SectionSpecifier.Part, offset: Int?)

    /// IMAP4rev1 RFC 3501, streams BODY[TEXT]
    case body(section: SectionSpecifier, offset: Int?)

    /// IMAP4rev1 RFC 3501, streams RF822 equivalent to BODY[]
    case rfc822

    /// IMAP4rev1 RFC 3501, streams RF822.TEXT
    case rfc822Text

    /// IMAP4rev1 RFC 3501, streams RF822.HEADER
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
