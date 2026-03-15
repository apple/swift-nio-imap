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

/// A network-accessible IMAP path that specifies a server and optional command.
///
/// A network path combines an IMAP server specification with an optional command to execute
/// on that server. It represents a URL with network location information (``IMAPServer``)
/// but without specific message content (unlike ``NetworkMessagePath`` which includes
/// mailbox and UID details).
///
/// Network paths are used in relative URL resolution (RFC 3986) and represent paths
/// like `//server/...` (with authority but potentially without a specific resource).
///
/// ### Examples
///
/// Network path referring to a server root:
/// ```
/// //example.com/
/// ```
///
/// Network path with a specific port:
/// ```
/// //example.com:993/
/// ```
///
/// Network path with user context and a command:
/// ```
/// //user@example.com/INBOX
/// ```
///
/// In relative URL resolution, a network path is resolved relative to the scheme:
/// ```
/// Base: imap://example.com/INBOX/
/// Network path: //other.com/
/// Result: imap://other.com/
/// ```
///
/// ## Related Types
///
/// - ``RelativeIMAPURL`` uses network paths as one variant of relative URLs
/// - ``IMAPServer`` provides the server connection specification
/// - ``URLCommand`` specifies optional commands to execute
/// - ``NetworkMessagePath`` extends network paths with message content details
///
/// - SeeAlso: [RFC 3986 Section 3.2](https://datatracker.ietf.org/doc/html/rfc3986#section-3.2) - Authority
public struct NetworkPath: Hashable, Sendable {
    /// The IMAP server location.
    public var server: IMAPServer

    /// Optional command to execute on the server.
    public var command: URLCommand?

    /// Creates a new network-accessible path.
    /// - parameter server: The IMAP server location.
    /// - parameter command: Optional command to execute. Defaults to `nil`.
    public init(server: IMAPServer, query: URLCommand?) {
        self.server = server
        self.command = query
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNetworkPath(_ path: NetworkPath) -> Int {
        self.writeString("//") + self.writeIMAPServer(path.server) + self.writeString("/")
            + self.writeIfExists(path.command) { command in
                self.writeURLCommand(command)
            }
    }
}
