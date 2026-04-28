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

/// Source options specifying which mailboxes to search in a multi-mailbox search operation (RFC 7377).
///
/// **Requires server capability:** ``Capability/multiSearch``
///
/// Source options define the mailbox context for an extended search operation, allowing searches to span
/// multiple mailboxes using mailbox filters (for example, personal namespace mailboxes or specific named mailboxes).
/// The `IN` clause specifies one or more mailbox filters, and optional scope options can further refine
/// the search context. See [RFC 7377 Section 2.1.1](https://datatracker.ietf.org/doc/html/rfc7377#section-2.1.1).
///
/// ### Example
///
/// ```
/// C: A001 SEARCH IN (personal subtree "Archive") RETURN (MIN MAX) UNSEEN
/// S: * ESEARCH UID MIN 5 MAX 128
/// S: A001 OK SEARCH completed
/// ```
///
/// The line `IN (personal subtree "Archive")` represents the source options with mailbox filters:
/// - ``MailboxFilter/personal`` - all personal mailboxes
/// - ``MailboxFilter/subtree(_:)`` - the "Archive" mailbox and its subfolders
///
/// ## Related types
///
/// - See ``MailboxFilter`` for individual mailbox filter types
/// - See ``ExtendedSearchOptions`` for complete search options
/// - See ``ExtendedSearchScopeOptions`` for optional scope configuration
///
/// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
public struct ExtendedSearchSourceOptions: Hashable, Sendable {
    /// Array of mailbox filters specifying which mailboxes to search.
    ///
    /// At least one mailbox filter must be present. Multiple filters can be combined to search
    /// across different mailbox categories (for example, personal mailboxes, specific named mailboxes, or
    /// subscribed mailboxes).
    public let sourceMailbox: [MailboxFilter]

    /// Optional scope options for refining the search context.
    ///
    /// Provides extensibility for future scope-related parameters that may further qualify
    /// the mailbox selection. When `nil`, no additional scope constraints are applied.
    public let scopeOptions: ExtendedSearchScopeOptions?

    /// Creates a new `ExtendedSearchSourceOptions` for multi-mailbox search.
    ///
    /// - parameter sourceMailbox: One or more mailbox filters specifying which mailboxes to search.
    /// - parameter scopeOptions: Optional scope options for further refinement (default: `nil`).
    /// - returns: A new `ExtendedSearchSourceOptions` if `sourceMailbox` is non-empty, otherwise `nil`.
    public init?(sourceMailbox: [MailboxFilter], scopeOptions: ExtendedSearchScopeOptions? = nil) {
        guard sourceMailbox.count >= 1 else {
            return nil
        }
        self.sourceMailbox = sourceMailbox
        self.scopeOptions = scopeOptions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchSourceOptions(_ options: ExtendedSearchSourceOptions) -> Int {
        self.writeString("IN (")
            + self.writeArray(options.sourceMailbox, parenthesis: false) { (filter, buffer) -> Int in
                buffer.writeMailboxFilter(filter)
            }
            + self.writeIfExists(options.scopeOptions) { scopeOptions in
                self.writeString(" (") + self.writeExtendedSearchScopeOptions(scopeOptions) + self.writeString(")")
            } + self.writeString(")")
    }
}
