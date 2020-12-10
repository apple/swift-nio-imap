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

/// A percent-encoded URL auth.
public struct EncodedURLAuth: Equatable {
    /// The percent-encoded data.
    public var data: String

    /// Creates a new `EncodedUrlAuth`.
    /// - parameter data: The percent-encoded string.
    public init(data: String) {
        self.data = data
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedURLAuth(_ data: EncodedURLAuth) -> Int {
        self.writeString(data.data)
    }
}
