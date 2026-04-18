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

/// A command continuation request from the server.
///
/// Servers send continuation requests (prefixed with `+`) when they are waiting for additional
/// data from the client. This occurs during SASL authentication flows and after the client sends
/// a synchronizing literal (a message part that will be uploaded). The server signals readiness
/// to receive the data by sending a continuation request.
/// See [RFC 3501 Section 7.5](https://datatracker.ietf.org/doc/html/rfc3501#section-7.5) for details.
///
/// ### Examples
///
/// ```
/// C: A001 AUTHENTICATE PLAIN
/// S: + (server is ready for base64-encoded auth data)
/// C: dXNlcm5hbWU6dXNlcm5hbWU6cGFzc3dvcmQ=
/// S: A001 OK AUTHENTICATE completed
/// ```
///
/// The line `S: +` is a ``ContinuationRequest/data(_:)`` case with an empty buffer. The subsequent
/// base64-encoded line is the client's response to that request.
///
/// ```
/// C: A002 APPEND INBOX {12}
/// S: + OK ready for message
/// C: Test message\r\n
/// S: A002 OK APPEND completed
/// ```
///
/// The line `S: + OK ready for message` is a ``ContinuationRequest/responseText(_:)`` case,
/// indicating the server is ready to receive the literal data.
///
/// - SeeAlso: ``ResponseText``, [RFC 3501 Section 7.5](https://datatracker.ietf.org/doc/html/rfc3501#section-7.5)
public enum ContinuationRequest: Hashable, Sendable {
    /// A continuation request containing human-readable response text and optional status code.
    ///
    /// When the server sends text with the continuation request, it typically indicates a status or
    /// requests additional information. This is common in SASL authentication mechanisms where the
    /// server may provide challenges or status messages.
    ///
    /// - SeeAlso: ``ResponseText``
    case responseText(ResponseText)

    /// A continuation request containing data, typically base64-encoded.
    ///
    /// When the server sends only a continuation indicator (empty or with base64 data), the client
    /// must respond with the requested data. For SASL authentication, the data is typically
    /// base64-encoded credentials. For literal synchronization, it signals readiness to receive
    /// message content.
    ///
    /// - SeeAlso: [RFC 3501 Section 7.5](https://datatracker.ietf.org/doc/html/rfc3501#section-7.5)
    case data(ByteBuffer)
}
