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

/// A response containing the server's namespace configuration for personal, other users', and shared mailboxes.
///
/// Represents the response to a `NAMESPACE` command (RFC 2342), which allows clients to discover
/// the mailbox namespace structure used by the server. The response contains three namespace categories,
/// each consisting of zero or more ``NamespaceDescription`` objects. Any category that is not available
/// on the server will contain an empty array.
///
/// The `NAMESPACE` command helps clients automatically determine mailbox prefixes and hierarchy delimiters
/// without requiring manual user configuration.
///
/// ### Example
///
/// ```
/// C: A001 NAMESPACE
/// S: * NAMESPACE (("" "/")) (("~" "/")) NIL
/// S: A001 OK NAMESPACE command completed
/// ```
///
/// The response is wrapped as ``NamespaceResponse`` where:
/// - `userNamespace` is `[NamespaceDescription(string: "", delimiter: "/")]`
/// - `otherUserNamespace` is `[NamespaceDescription(string: "~", delimiter: "/")]`
/// - `sharedNamespace` is `[]` (NIL indicates no shared namespace available)
///
/// - SeeAlso: [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342)
public struct NamespaceResponse: Hashable, Sendable {
    /// Descriptions of the personal namespace(s) for the authenticated user.
    ///
    /// The personal namespace typically contains the user's mailboxes, including the INBOX.
    /// In most cases, there is only one personal namespace, though multiple are possible.
    /// An empty array indicates no personal namespace is available on the server.
    public var userNamespace: [NamespaceDescription]

    /// Descriptions of other users' namespace(s).
    ///
    /// The other users' namespace provides access to mailboxes from other authenticated users
    /// on the server. Accessing these mailboxes requires explicit permissions from the other user.
    /// An empty array indicates the server does not provide access to other users' mailboxes.
    public var otherUserNamespace: [NamespaceDescription]

    /// Descriptions of shared namespace(s).
    ///
    /// Shared namespaces contain mailboxes intended to be used by multiple users and are not
    /// part of any individual user's personal namespace. An empty array indicates no shared
    /// namespaces are available on the server.
    public var sharedNamespace: [NamespaceDescription]

    /// Creates a new `NamespaceResponse`.
    ///
    /// - Parameters:
    ///   - userNamespace: Descriptions of the personal namespace(s) for the authenticated user.
    ///   - otherUserNamespace: Descriptions of other users' namespace(s).
    ///   - sharedNamespace: Descriptions of shared namespace(s).
    public init(
        userNamespace: [NamespaceDescription],
        otherUserNamespace: [NamespaceDescription],
        sharedNamespace: [NamespaceDescription]
    ) {
        self.userNamespace = userNamespace
        self.otherUserNamespace = otherUserNamespace
        self.sharedNamespace = sharedNamespace
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNamespaceResponse(_ response: NamespaceResponse) -> Int {
        self.writeString("NAMESPACE ") + self.writeNamespace(response.userNamespace) + self.writeSpace()
            + self.writeNamespace(response.otherUserNamespace) + self.writeSpace()
            + self.writeNamespace(response.sharedNamespace)
    }
}
