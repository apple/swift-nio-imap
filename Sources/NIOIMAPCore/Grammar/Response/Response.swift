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

public enum ResponseOrContinuationRequest: Equatable {
    case continuationRequest(ContinuationRequest)
    case response(Response)
}

public enum Response: Equatable {
    case untaggedResponse(ResponsePayload)
    case fetchResponse(FetchResponse)
    case taggedResponse(TaggedResponse)
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
