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

/// A mailbox reference paired with an optional percent-encoded search query.
///
/// This type combines a mailbox identifier with UID validity and an optional search query for use
/// in IMAP URLs (RFC 5092). It specifies both which mailbox to search and what to search for.
///
/// - SeeAlso: [RFC 5092 IMAP URL Scheme](https://datatracker.ietf.org/doc/html/rfc5092)
public struct EncodedSearchQuery: Hashable, Sendable {
    /// The mailbox to search.
    public var mailboxUIDValidity: MailboxUIDValidity

    /// A percent-encoded search query.
    public var encodedSearch: EncodedSearch?

    /// Creates a new `EncodedSearchQuery`.
    /// - parameter mailboxUIDValidity: The mailbox to search.
    /// - parameter encodedSearch: A percent-encoded search query.
    public init(mailboxUIDValidity: MailboxUIDValidity, encodedSearch: EncodedSearch? = nil) {
        self.mailboxUIDValidity = mailboxUIDValidity
        self.encodedSearch = encodedSearch
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedSearchQuery(_ ref: EncodedSearchQuery) -> Int {
        self.writeEncodedMailboxUIDValidity(ref.mailboxUIDValidity)
            + self.writeIfExists(ref.encodedSearch) { search in
                self.writeString("?") + self.writeEncodedSearch(search)
            }
    }
}
