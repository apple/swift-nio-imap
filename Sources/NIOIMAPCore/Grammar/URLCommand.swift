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

/// A command to execute once a connection to an IMAP server has been established.
///
/// URL commands specify operations to perform when resolving an IMAP URL. They are used in
/// IMAP URLs (RFC 2192/5092) to indicate which message data should be fetched or searched.
/// Each command type specifies a different operation and the parameters needed for that operation.
///
/// URL commands appear after the mailbox portion of an IMAP URL path.
///
/// ### Command types
///
/// - ``messageList(_:)``: Search for messages matching specific criteria (` `SEARCH` or `` `SELECT` `` semantics)
/// - ``fetch(path:authenticatedURL:)``: Fetch message content from a specific message location
///
/// ### Examples
///
/// Message list command (search for unseen messages):
/// ```
/// imap://user@example.com/INBOX?UNSEEN
/// ```
///
/// Fetch command (retrieve a specific message):
/// ```
/// imap://user@example.com/INBOX/;uid=20
/// ```
///
/// Fetch command with authentication (URLAUTH):
/// ```
/// imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN
/// ```
///
/// In a URLFETCH command:
/// ```
/// C: a001 URLFETCH "imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN"
/// S: * URLFETCH ("imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN" "message-data")
/// S: a001 OK URLFETCH completed
/// ```
///
/// ## Related types
///
/// - ``MessagePath`` specifies message location details
/// - ``AuthenticatedURL`` provides URLAUTH verification for authorized access
/// - ``URLFetchType`` provides variations on message path specification
/// - ``IMAPURL`` includes an optional URL command
/// - ``RelativeIMAPURL`` may include URL commands in absolute or network paths
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4467 Section 7](https://datatracker.ietf.org/doc/html/rfc4467#section-7) - URLFETCH Command
public enum URLCommand: Hashable, Sendable {
    /// A search query to identify messages matching specific criteria.
    ///
    /// When used in an IMAP URL, indicates that messages should be selected based on
    /// search criteria (for example, `UNSEEN`, `ALL`, or `TEXT "search text"`). Effectively
    /// performs a `SEARCH` command within the specified mailbox.
    case messageList(EncodedSearchQuery)

    /// A fetch command to retrieve specific message content.
    ///
    /// Specifies a message location (``MessagePath``) and optionally URLAUTH verification
    /// (``AuthenticatedURL``) to fetch message content. This is the primary command type
    /// used in URLFETCH requests.
    case fetch(path: MessagePath, authenticatedURL: AuthenticatedURL?)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLCommand(_ ref: URLCommand) -> Int {
        switch ref {
        case .messageList(let list):
            return self.writeEncodedSearchQuery(list)
        case .fetch(path: let path, authenticatedURL: let authenticatedURL):
            return self.writeMessagePath(path)
                + self.writeIfExists(authenticatedURL) { authenticatedURL in
                    self.writeIAuthenticatedURL(authenticatedURL)
                }
        }
    }
}
