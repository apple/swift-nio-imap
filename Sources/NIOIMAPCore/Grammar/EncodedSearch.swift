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

/// A percent-encoded search.
public struct EncodedSearch: Equatable {
    /// The percent-encoded data.
    public var query: String

    /// Creates a new `EncodedSearch`.
    /// - parameter query: The percent-encoded string.
    public init(query: String) {
        self.query = query
    }
}

extension _EncodeBuffer {
    @discardableResult mutating func writeEncodedSearch(_ query: EncodedSearch) -> Int {
        self._writeString(query.query)
    }
}
