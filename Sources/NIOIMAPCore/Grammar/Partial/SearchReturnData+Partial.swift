//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import struct NIO.ByteBuffer

extension SearchReturnData {
    /// Partial search results with a specified range.
    ///
    /// This type contains the range that was requested via the `PARTIAL` modifier and the
    /// message numbers matching the search within that range. The `PARTIAL` extension (RFC 9394)
    /// enables efficient pagination of large search results.
    ///
    /// - SeeAlso: [RFC 9394 IMAP PARTIAL Extension](https://datatracker.ietf.org/doc/html/rfc9394)
    /// - SeeAlso: ``PartialRange``
    public struct Partial: Hashable, Sendable {
        /// The requested range.
        public var range: PartialRange
        /// The matching messages.
        public var messageNumbers: MessageIdentifierSet<UnknownMessageIdentifier>
    }
}
