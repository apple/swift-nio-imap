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

/// A URL and the message data associated with it in a URLFETCH response.
///
/// When a client issues a `URLFETCH` command (RFC 4467) with one or more IMAP URLs (potentially
/// URLAUTH-authorized), the server returns the content of those URLs in a URLFETCH response.
/// Each ``URLFetchData`` represents one URL and its associated message content.
///
/// The response format includes:
/// - The URL (as an IMAP string) that was requested
/// - The message data (as an IMAP string or NIL if unavailable)
///
/// ### Example
///
/// URLFETCH command and response:
/// ```
/// C: a001 URLFETCH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN"
/// S: * URLFETCH ("imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN" {1234}
/// S: message-content-here...)
/// S: a001 OK URLFETCH completed
/// ```
///
/// The server response line `* URLFETCH (url data)` is wrapped as ``Response/untagged(_:)``
/// containing ``MessageData/urlFetch(_:)`` with a list of ``URLFetchData`` items.
///
/// Each item pairs the requested URL with the fetched message data (or NIL if the URL
/// was invalid or the server could not retrieve the data).
///
/// ### URL Format
///
/// The URL is typically returned as it was submitted, including any URLAUTH authorization tokens:
/// ```
/// imap://user@example.com/INBOX/;uid=20;section=1.2;urlauth=anonymous:internal:...
/// ```
///
/// ## Related types
///
/// - ``NetworkMessagePath`` represents the base URL before authorization
/// - ``AuthenticatedURL`` provides URLAUTH verification for the URL
/// - ``URLCommand`` specifies what to fetch
/// - ``Response/untagged(_:)`` wraps the response
/// - ``MessageData/urlFetch(_:)`` contains the URLFETCH data
///
/// - SeeAlso: [RFC 4467 Section 7](https://datatracker.ietf.org/doc/html/rfc4467#section-7) - URLFETCH Command
public struct URLFetchData: Hashable, Sendable {
    /// The IMAP URL that was fetched.
    ///
    /// The URL as submitted in the URLFETCH command, typically including
    /// URLAUTH authorization information if the URL was authorized.
    public var url: ByteBuffer

    /// The message data associated with the URL, or `nil` if unavailable.
    ///
    /// When `nil`, indicates that the server could not retrieve the message data
    /// (for example, because the URL was invalid, authorization failed, or the message was deleted).
    /// When present, contains the message content (or partial content if the URL
    /// specified a section or byte range).
    public var data: ByteBuffer?

    /// Creates a new URLFETCH response data item.
    /// - parameter url: The IMAP URL that was fetched.
    /// - parameter data: The message data, or `nil` if unavailable.
    public init(url: ByteBuffer, data: ByteBuffer?) {
        self.url = url
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLFetchData(_ data: URLFetchData) -> Int {
        self.writeIMAPString(data.url) + self.writeSpace() + self.writeNString(data.data)
    }
}
