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

/// Wraps data and a URL that the data is associated with. Returned as part of a `.urlFetch` command.
public struct URLFetchData: Hashable {
    // TODO: This is defined in the spec as being an `astring`, however is really a full URL wrapped in quotes
    // we should consider extracting the data of the quotes and correctly parsing the URL
    /// The IMAP URL that's being fetched.
    public var url: ByteBuffer

    /// Data associated with the `.url`.
    public var data: ByteBuffer?

    /// Creates a new `URLFetchData`.
    /// - parameter url: The IMAP URL that's being fetched.
    /// - parameter data: Data associated with the `.url`.
    public init(url: ByteBuffer, data: ByteBuffer?) {
        self.url = url
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLFetchData(_ data: URLFetchData) -> Int {
        self.writeIMAPString(data.url) +
            self.writeSpace() +
            self.writeNString(data.data)
    }
}
