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

/// An absolute IMAP URL path that does not include server information.
///
/// An absolute message path is a relative URL (RFC 3986) that specifies a command to execute
/// without providing server connection details. This is used in contexts where the server is
/// already known or provided separately, such as when resolving relative URLs.
///
/// The absolute path starts with `/` and optionally includes a command specification.
/// Unlike ``NetworkMessagePath``, it does not include the server hostname or port.
///
/// ### Examples
///
/// Absolute path without a command (refers to the document root):
/// ```
/// /
/// ```
///
/// Absolute path with a fetch command:
/// ```
/// /INBOX/;uid=20
/// ```
///
/// In relative URL resolution, an absolute path is resolved relative to the server:
/// ```
/// Base: imap://user@example.com/
/// Absolute path: /INBOX/;uid=20
/// Result: imap://user@example.com/INBOX/;uid=20
/// ```
///
/// ## Related Types
///
/// - ``RelativeIMAPURL`` uses absolute message paths as one variant of relative URLs
/// - ``URLCommand`` specifies the fetch operation details
/// - ``NetworkPath`` provides network-accessible paths (with server information)
///
/// - SeeAlso: [RFC 3986 Section 3.3](https://datatracker.ietf.org/doc/html/rfc3986#section-3.3) - Absolute Path
public struct AbsoluteMessagePath: Hashable, Sendable {
    /// Optional command to execute on the specified path.
    public var command: URLCommand?

    /// Creates a new absolute message path.
    /// - parameter command: Optional command to execute. Defaults to `nil`.
    public init(command: URLCommand?) {
        self.command = command
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeAbsoluteMessagePath(_ path: AbsoluteMessagePath) -> Int {
        self.writeString("/")
            + self.writeIfExists(path.command) { command in
                self.writeURLCommand(command)
            }
    }
}
