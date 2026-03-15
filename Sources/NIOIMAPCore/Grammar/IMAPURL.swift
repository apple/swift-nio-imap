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

/// A complete IMAP URL specifying a server connection and an optional command to execute.
///
/// An IMAP URL (RFC 2192/5092) has the form:
/// ```
/// imap://[user[@;auth]]@host[:port]/[command]
/// ```
///
/// where `command` is typically one of:
/// - A mailbox name (to select that mailbox)
/// - A fetch command for a specific message
/// - A search query
///
/// The ``IMAPURL`` structure represents this complete URL, with the server component
/// (``IMAPServer``) providing connection details and an optional ``URLCommand`` providing
/// the operation to perform.
///
/// ### Examples
///
/// Simple URL to connect to a server (no command):
/// ```
/// imap://user@example.com/
/// ```
///
/// URL with mailbox selection (via message list command):
/// ```
/// imap://user@example.com/INBOX
/// ```
///
/// URL with specific message fetch:
/// ```
/// imap://user@example.com/INBOX/;uid=20
/// ```
///
/// URL with URLAUTH authorization:
/// ```
/// imap://user@example.com/INBOX/;uid=20;urlauth=anonymous:internal:TOKEN
/// ```
///
/// ## URL Structure
///
/// - **`imap://`**: Fixed scheme identifier
/// - **Server** (``IMAPServer``): User, host, port, and authentication mechanism
/// - **`/`**: Path separator
/// - **Command** (``URLCommand``, optional): Mailbox, search, or fetch operation
///
/// ## Related Types
///
/// - ``IMAPServer`` provides server connection specification
/// - ``UserAuthenticationMechanism`` specifies user and auth mechanism
/// - ``URLCommand`` provides optional commands (search or fetch)
/// - ``RelativeIMAPURL`` provides relative URL alternatives
/// - ``NetworkMessagePath`` represents the URL before authorization
///
/// - SeeAlso: [RFC 2192](https://datatracker.ietf.org/doc/html/rfc2192) - IMAP URL Scheme
/// - SeeAlso: [RFC 4467 Section 3](https://datatracker.ietf.org/doc/html/rfc4467#section-3) - IMAP URL Extensions
public struct IMAPURL: Hashable, Sendable {
    /// The server to connect to (hostname, optional port, optional user and auth mechanism).
    public var server: IMAPServer

    /// Optional command to execute once a connection to the server has been established.
    public var command: URLCommand?

    /// Creates a new IMAP URL.
    /// - parameter server: The server to connect to.
    /// - parameter command: Optional command to execute. Defaults to `nil`.
    public init(server: IMAPServer, query: URLCommand?) {
        self.server = server
        self.command = query
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeIMAPURL(_ url: IMAPURL) -> Int {
        self.writeString("imap://") + self.writeIMAPServer(url.server) + self.writeString("/")
            + self.writeIfExists(url.command) { command in
                self.writeURLCommand(command)
            }
    }
}
