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

/// Options for performing a multi-mailbox extended search (RFC 7377 MULTIMAILBOX SEARCH).
///
/// **Requires server capability:** ``Capability/multimailboxSearch``
///
/// The extended search options combine search criteria, charset specification, return options, and source options
/// to enable searching across multiple mailboxes in a single command. This extension allows searches that span
/// multiple mailboxes identified by mailbox filters. See [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
/// for details on multi-mailbox search operations.
///
/// ### Example
///
/// ```
/// C: A001 SEARCH IN (personal) RETURN (MIN MAX) UNSEEN
/// S: * ESEARCH UID MIN 1 MAX 42
/// S: A001 OK SEARCH completed
/// ```
///
/// The `SEARCH IN (personal) RETURN (MIN MAX) UNSEEN` command uses ``ExtendedSearchOptions`` with
/// `sourceOptions` set to a personal mailbox filter, `returnOptions` for `MIN`/`MAX`, and `key` for the
/// `UNSEEN` search criteria. The response is ``Response/untagged(_:)`` containing
/// ``ResponsePayload/extendedSearch(_:)``.
///
/// ## Related Types
///
/// - See ``SearchKey`` for search criteria
/// - See ``SearchReturnOption`` for return options
/// - See ``ExtendedSearchSourceOptions`` for source/scope configuration
/// - See ``MailboxFilter`` for mailbox filtering
///
/// - SeeAlso: [RFC 7377](https://datatracker.ietf.org/doc/html/rfc7377)
public struct ExtendedSearchOptions: Hashable, Sendable {
    /// The search criteria to apply.
    ///
    /// Specifies what messages to match, such as ``SearchKey/unseen``, ``SearchKey/recent``, or
    /// other search criteria defined in [RFC 3501 Section 6.4.4](https://datatracker.ietf.org/doc/html/rfc3501#section-6.4.4)
    /// and extended search criteria from various IMAP extensions.
    public var key: SearchKey

    /// The character set to use when interpreting string search criteria, if specified.
    ///
    /// Optional character set encoding for text-based search operations. When `nil`, the default UTF-8
    /// encoding is assumed. This allows for searches using specific character sets when needed.
    public var charset: String?

    /// Return options that filter and shape the data returned from the search.
    ///
    /// Specifies which fields should be returned in the search response (e.g., ``SearchReturnOption/min``,
    /// ``SearchReturnOption/max``, ``SearchReturnOption/all``, etc.).
    public var returnOptions: [SearchReturnOption]

    /// The mailboxes and scope to search across.
    ///
    /// Specifies which mailbox(es) to include in the search operation using mailbox filters
    /// (e.g., personal namespace, specific mailbox names). When `nil`, the current mailbox context is used.
    public var sourceOptions: ExtendedSearchSourceOptions?

    /// Creates a new `ExtendedSearchOptions` for multi-mailbox search.
    ///
    /// - parameter key: The search criteria to apply.
    /// - parameter charset: Optional character set for string-based searches.
    /// - parameter returnOptions: Options specifying what data to return (default: empty).
    /// - parameter sourceOptions: Mailbox and scope filters (default: `nil`).
    public init(
        key: SearchKey,
        charset: String? = nil,
        returnOptions: [SearchReturnOption] = [],
        sourceOptions: ExtendedSearchSourceOptions? = nil
    ) {
        self.key = key
        self.charset = charset
        self.returnOptions = returnOptions
        self.sourceOptions = sourceOptions
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeExtendedSearchOptions(_ options: ExtendedSearchOptions) -> Int {
        self.writeIfExists(options.sourceOptions) { (options) -> Int in
            self.writeSpace() + self.writeExtendedSearchSourceOptions(options)
        }
            + self.writeIfExists(options.returnOptions) { (options) -> Int in
                self.writeSearchReturnOptions(options)
            } + self.writeSpace()
            + self.writeIfExists(options.charset) { (charset) -> Int in
                self.writeString("CHARSET \(charset) ")
            } + self.writeSearchKey(options.key)
    }
}
