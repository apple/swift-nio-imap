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

/// RFC 5464
public struct MetadataValue: RawRepresentable, Equatable {
    public var rawValue: ByteBuffer?

    public init(rawValue: ByteBuffer?) {
        self.rawValue = rawValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataValue(_ value: MetadataValue) -> Int {
        guard let bytes = value.rawValue else {
            return self.writeNil()
        }
        return self.writeLiteral8(bytes.readableBytesView)
    }
}
