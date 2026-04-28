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

/// Mailbox name patterns for the `LIST` command.
///
/// ``MailboxPatterns`` allows the `LIST` command to search for mailboxes matching one or more patterns.
/// The base [RFC 3501 Section 6.3.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.8) defines
/// a single mailbox name or wildcard pattern. The `LIST` command extensions in
/// [RFC 5258 Section 3](https://datatracker.ietf.org/doc/html/rfc5258#section-3) allow multiple patterns to be searched.
///
/// Patterns use two wildcards:
/// - `%` - matches any sequence of characters EXCEPT the hierarchy delimiter
/// - `*` - matches any sequence of zero or more characters, including the hierarchy delimiter
///
/// To list **all mailboxes** on the server, use the pattern `*` (the wildcard that matches everything).
/// Using `*` is the most common LIST usage and returns the complete mailbox hierarchy.
///
/// ### Example
///
/// ```
/// C: A001 LIST "" "Sent" "Archive"
/// S: * LIST (\HasChildren) "/" "Archive"
/// S: * LIST (\HasChildren) "/" "Sent"
/// S: A001 OK LIST completed
/// ```
///
/// Using `.pattern([ByteBuffer(string: "Sent"), ByteBuffer(string: "Archive")])` sends the multi-pattern
/// LIST request, and the server returns matching mailboxes wrapped as ``Response/untagged(_:)``
/// containing ``ResponsePayload/mailboxData(_:)`` entries for each match.
///
/// ### Listing all mailboxes
///
/// ```
/// C: A001 LIST "" "*"
/// S: * LIST (\NoInferiors) "/" "INBOX"
/// S: * LIST (\HasChildren) "/" "Archive"
/// S: * LIST (\HasChildren) "/" "Archive/2020"
/// S: * LIST (\HasChildren) "/" "Sent"
/// S: A001 OK LIST completed
/// ```
///
/// To list all mailboxes, use `.mailbox(ByteBuffer(string: "*"))` which returns the complete hierarchy.
/// Per [RFC 3501 Section 6.3.8](https://datatracker.ietf.org/doc/html/rfc3501#section-6.3.8),
/// the reference name (first parameter in the protocol) is typically an empty string.
///
/// - SeeAlso: ``MailboxInfo``
public enum MailboxPatterns: Hashable, Sendable {
    /// A single mailbox pattern or literal mailbox name to match.
    ///
    /// The pattern can include wildcards:
    /// - Empty string "" matches the hierarchy delimiter
    /// - `%` matches any characters except the delimiter
    /// - `*` matches any characters including the delimiter
    /// - A literal name matches that specific mailbox
    case mailbox(ByteBuffer)

    /// Multiple mailbox patterns to match in a single `LIST` command.
    ///
    /// The LIST-EXTENDED extension (RFC 5258) allows multiple patterns to be specified,
    /// and the server returns mailboxes matching any of the patterns.
    /// Each pattern follows the same wildcard rules as the single pattern case.
    case pattern([ByteBuffer])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMailboxPatterns(_ patterns: MailboxPatterns) -> Int {
        switch patterns {
        case .mailbox(let list):
            return self.writeIMAPString(list)
        case .pattern(let patterns):
            return self.writePatterns(patterns)
        }
    }
}
