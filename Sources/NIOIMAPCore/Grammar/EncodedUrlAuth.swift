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

/// RFC 5092
public struct EncodedURLAuth: Equatable {
    public var data: String

    public init(data: String) {
        self.data = data
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedURLAuth(_ data: EncodedURLAuth) -> Int {
        self.writeString(data.data)
    }
}
