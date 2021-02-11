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

/// Allows a client to optionally send an initial response when authenticating to speed
/// up the process.
public struct InitialClientResponse: Hashable {
    /// Creates a new empty `InitialClientResponse` that will be encoded as `=`.
    public static var empty: Self = .init(ByteBuffer())

    /// The data to be base-64 encoded.
    var data: ByteBuffer

    /// Creates a new `InitialClientResponse`
    /// - parameter data: The raw (ie. not base64 encoded) data to be sent.
    public init(_ data: ByteBuffer) {
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInitialClientResponse(_ resp: InitialClientResponse) -> Int {
        if resp.data.readableBytes == 0 {
            return self.writeString("=")
        } else {
            let encoded = Base64.encode(bytes: resp.data.readableBytesView)
            return self.writeString(encoded)
        }
    }
}
