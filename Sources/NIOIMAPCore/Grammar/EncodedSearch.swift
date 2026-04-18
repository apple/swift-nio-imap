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

/// A percent-encoded search query for use in IMAP URLs.
///
/// Search queries in IMAP URLs (RFC 5092) must be percent-encoded to avoid conflicts with
/// URL syntax. This type wraps such an encoded search string.
///
/// - SeeAlso: [RFC 5092 IMAP URL Scheme](https://datatracker.ietf.org/doc/html/rfc5092)
public struct EncodedSearch: Hashable, Sendable {
    /// The percent-encoded data.
    public var query: String

    /// Creates a new `EncodedSearch`.
    /// - parameter query: The percent-encoded string.
    public init(query: String) {
        self.query = query
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedSearch(_ query: EncodedSearch) -> Int {
        self.writeString(query.query)
    }
}
