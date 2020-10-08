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

/// RFC 4467
public struct URLFetchData: Equatable {
    public var url: ByteBuffer
    public var data: ByteBuffer?

    public init(url: ByteBuffer, data: ByteBuffer?) {
        self.url = url
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeURLFetchData(_ data: URLFetchData) -> Int {
        self.writeSpace() +
            self.writeIMAPString(data.url) +
            self.writeSpace() +
            self.writeNString(data.data)
    }
}
