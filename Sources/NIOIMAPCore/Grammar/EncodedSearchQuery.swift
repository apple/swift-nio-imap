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

/// RFC 5092
public struct EncodedSearchQuery: Equatable {
    /// The mailbox to search.
    public var mailboxValidity: EncodedMailboxUIDValidity

    /// A percent-encoded search query.
    public var encodedSearch: EncodedSearch?

    /// Creates a new `EncodedSearchQuery`.
    /// - parameter mailboxReference: The mailbox to search.
    /// - parameter encodedSearch: A percent-encoded search query.
    public init(mailboxValidity: EncodedMailboxUIDValidity, encodedSearch: EncodedSearch? = nil) {
        self.mailboxValidity = mailboxValidity
        self.encodedSearch = encodedSearch
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeEncodedSearchQuery(_ ref: EncodedSearchQuery) -> Int {
        self.writeIMailboxReference(ref.mailboxReference) +
            self.writeIfExists(ref.encodedSearch) { search in
                self._writeString("?") + self.writeEncodedSearch(search)
            }
    }
}
