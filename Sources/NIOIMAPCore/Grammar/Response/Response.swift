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

/// Used to wrap if the server has a sent a response or continuation request.
public enum ResponseOrContinuationRequest: Equatable {
    
    /// The server has sent a `ContinuationRequest`, and the client now needs to return some data.
    case continuationRequest(ContinuationRequest)
    
    /// The server has sent a `Response` that can now be handled by the client.
    case response(Response)
}

/// Wraps the various response types that may be sent by a server.
public enum Response: Equatable {
    
    /// Servers may send one or more untagged response for every tagged response.
    /// Untagged responses are sent before their corresponding tagged response.
    case untaggedResponse(ResponsePayload)
    
    /// `FetchResponse` are handled as a special case to enable streaming of large messages, e.g.
    /// those that contain attachments.
    case fetchResponse(FetchResponse)
    
    /// Exactly one `TaggedResponse` is returned for each command, and is the last piece of data
    /// to be sent. Upon receiving a `TaggedResponse` the client knows that the server has finished
    /// processing the command specified by the tag.
    case taggedResponse(TaggedResponse)
    
    /// Fatal responses indicate some unrecoverable error has occurred, and
    /// the server is now going to terminate the connection.
    case fatalResponse(ResponseText)
}

/// The first event will always be `start`
/// The last event will always be `finish`
/// Every `start` has exactly one corresponding `finish`
/// After recieving `start` you may recieve n `simpleAttribute`, `streamingBegin`, and `streamingBytes` events.
/// Every `streamingBegin` has exaclty one corresponding `streamingEnd`
/// `streamingBegin` has a `type` that specifies the type of data to be streamed
public enum FetchResponse: Equatable {
    case start(Int)
    case simpleAttribute(MessageAttribute)
    case streamingBegin(kind: StreamingKind, byteCount: Int)
    case streamingBytes(ByteBuffer)
    case streamingEnd
    case finish
}

public enum StreamingKind: Equatable {
    case binary(section: SectionSpecifier.Part) /// BINARY RFC 3516, streams BINARY when using a `literal`
    case body(partial: Int?) /// IMAP4rev1 RFC 3501, streams BODY[TEXT] when using a `literal`
    case rfc822 /// IMAP4rev1 RFC 3501, streams RF822.TEXT when using a `literal`
}
