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

/// The operation to perform on message flags in a `STORE` command.
///
/// The `STORE` command modifies message flags in one of three ways: add new flags, remove existing flags,
/// or replace all flags. The operation is specified as part of the `STORE` command syntax defined in
/// [RFC 3501 Section 6.4.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.6).
///
/// - SeeAlso: [RFC 3501 Section 6.4.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.6)
public enum StoreOperation: String, Hashable, Sendable {
    /// Add the specified flags to the message's existing flags.
    ///
    /// Other flags on the message are preserved. This corresponds to the `+FLAGS` operation in IMAP.
    case add = "+"

    /// Remove the specified flags from the message's flags.
    ///
    /// Other flags on the message are preserved. This corresponds to the `-FLAGS` operation in IMAP.
    case remove = "-"

    /// Replace all flags on the message with the specified flags.
    ///
    /// All existing flags are removed except `\Recent` (which is read-only). This corresponds to the `FLAGS`
    /// operation in IMAP. This corresponds to the `FLAGS` operation in IMAP.
    case replace = ""
}

/// Data for a `STORE` command to modify message attributes.
///
/// The `STORE` command can modify both standard message flags and Gmail-specific labels. This enum represents
/// the different types of data that can be stored on messages.
///
/// - SeeAlso: ``StoreFlags``
/// - SeeAlso: ``StoreGmailLabels``
public enum StoreData: Hashable, Sendable {
    /// Modify standard IMAP message flags (add, remove, or replace).
    case flags(StoreFlags)

    /// Modify Gmail-specific labels (Gmail extension, requires X-GM-EXT-1 capability).
    case gmailLabels(StoreGmailLabels)
}

/// Gmail-specific labels for a `STORE` command.
///
/// Gmail labels are extended attributes for Gmail messages, separate from standard IMAP flags.
/// They are supported only on Gmail IMAP servers that advertise the `X-GM-EXT-1` capability.
/// Labels can be added, removed, or replaced using the `X-GM-LABELS` attribute in `STORE` commands.
///
/// - SeeAlso: ``StoreOperation``
/// - SeeAlso: ``GmailLabel``
/// - SeeAlso: https://developers.google.com/gmail/imap/imap-extensions
public struct StoreGmailLabels: Hashable, Sendable {
    /// The operation to perform on Gmail labels (add, remove, or replace).
    public var operation: StoreOperation

    /// Whether the server should suppress sending the updated labels list back to the client.
    ///
    /// When `true`, the server uses `.SILENT` mode and does not send a `FETCH` response with the new labels.
    /// When `false`, the server responds with the updated labels.
    public var silent: Bool

    /// The Gmail labels to operate on.
    public var gmailLabels: [GmailLabel]

    /// Creates a new add operation for Gmail labels.
    ///
    /// - parameter silent: `true` to suppress the server's response, `false` to receive the updated labels list.
    /// - parameter gmailLabels: The labels to add (defaults to empty array).
    /// - returns: A new ``StoreGmailLabels`` configured for adding labels.
    public static func add(silent: Bool, gmailLabels: [GmailLabel] = []) -> Self {
        Self(operation: .add, silent: silent, gmailLabels: gmailLabels)
    }

    /// Creates a new remove operation for Gmail labels.
    ///
    /// - parameter silent: `true` to suppress the server's response, `false` to receive the updated labels list.
    /// - parameter gmailLabels: The labels to remove (defaults to empty array).
    /// - returns: A new ``StoreGmailLabels`` configured for removing labels.
    public static func remove(silent: Bool, gmailLabels: [GmailLabel] = []) -> Self {
        Self(operation: .remove, silent: silent, gmailLabels: gmailLabels)
    }

    /// Creates a new replace operation for Gmail labels.
    ///
    /// - parameter silent: `true` to suppress the server's response, `false` to receive the updated labels list.
    /// - parameter gmailLabels: The labels to set as the complete set (defaults to empty array).
    /// - returns: A new ``StoreGmailLabels`` configured for replacing all labels.
    public static func replace(silent: Bool, gmailLabels: [GmailLabel] = []) -> Self {
        Self(operation: .replace, silent: silent, gmailLabels: gmailLabels)
    }
}

/// Standard IMAP message flags for a `STORE` command.
///
/// This type specifies a set of flags to add to, remove from, or replace on messages via the `STORE` command.
/// The operation (add/remove/replace) and whether to suppress the server response are configured separately.
///
/// Flags are described in [RFC 3501 Section 2.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3)
/// and the `STORE` command in [RFC 3501 Section 6.4.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.6).
///
/// ### Example
///
/// ```
/// C: A001 STORE 1:5 +FLAGS (\Seen)
/// S: * 1 FETCH (FLAGS (\Answered \Seen))
/// S: * 2 FETCH (FLAGS (\Seen))
/// S: * 3 FETCH (FLAGS (\Seen))
/// S: * 4 FETCH (FLAGS (\Seen))
/// S: * 5 FETCH (FLAGS (\Seen))
/// S: A001 OK STORE completed
/// ```
///
/// The `+FLAGS` operation corresponds to a ``StoreFlags`` with ``operation`` = ``StoreOperation/add`` and
/// ``flags`` = `[\Seen]`.
///
/// - SeeAlso: [RFC 3501 Section 2.3](https://datatracker.ietf.org/doc/html/rfc3501#section-2.3)
/// - SeeAlso: [RFC 3501 Section 6.4.6](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.6)
/// - SeeAlso: ``StoreOperation``
/// - SeeAlso: ``Flag``
public struct StoreFlags: Hashable, Sendable {
    /// The operation to perform on flags (add, remove, or replace).
    public var operation: StoreOperation

    /// Whether the server should suppress sending the updated flags list back to the client.
    ///
    /// When `true`, the server uses `.SILENT` mode and does not send a `FETCH` response with the new flags.
    /// When `false` (default), the server responds with the updated flags for each affected message.
    public var silent: Bool

    /// The flags to operate on.
    public var flags: [Flag]

    /// Creates a new add operation for message flags.
    ///
    /// - parameter silent: `true` to suppress the server's response, `false` to receive the updated flags list.
    /// - parameter list: The flags to add to each message.
    /// - returns: A new ``StoreFlags`` configured for adding flags.
    public static func add(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .add, silent: silent, flags: list)
    }

    /// Creates a new remove operation for message flags.
    ///
    /// - parameter silent: `true` to suppress the server's response, `false` to receive the updated flags list.
    /// - parameter list: The flags to remove from each message.
    /// - returns: A new ``StoreFlags`` configured for removing flags.
    public static func remove(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .remove, silent: silent, flags: list)
    }

    /// Creates a new replace operation for message flags.
    ///
    /// - parameter silent: `true` to suppress the server's response, `false` to receive the updated flags list.
    /// - parameter list: The complete set of flags to assign to each message (replaces existing flags except `\Recent`).
    /// - returns: A new ``StoreFlags`` configured for replacing all flags.
    public static func replace(silent: Bool, list: [Flag]) -> Self {
        Self(operation: .replace, silent: silent, flags: list)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeStoreAttributeFlags(_ flags: StoreFlags) -> Int {
        let silentString = flags.silent ? ".SILENT" : ""
        return
            self.writeString("\(flags.operation.rawValue)FLAGS\(silentString) ") + self.writeFlags(flags.flags)
    }

    @discardableResult mutating func writeStoreData(_ data: StoreData) -> Int {
        switch data {
        case .flags(let storeFlags):
            return self.writeStoreAttributeFlags(storeFlags)
        case .gmailLabels(let storeGmailLabels):
            return self.writeStoreGmailLabels(storeGmailLabels)
        }
    }

    @discardableResult mutating func writeStoreGmailLabels(_ labels: StoreGmailLabels) -> Int {
        let silentString = labels.silent ? ".SILENT" : ""
        return
            self.writeString("\(labels.operation.rawValue)X-GM-LABELS\(silentString) ")
            + self.writeGmailLabels(labels.gmailLabels)
    }
}
