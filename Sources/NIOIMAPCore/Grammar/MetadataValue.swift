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

/// The value for a metadata entry.
public struct MetadataValue: Equatable {
    /// The raw value bytes.
    public let bytes: ByteBuffer?

    /// Creates a new `MetadataValue`.
    /// - parameter rawValue: The raw value bytes - optional.
    public init(_ bytes: ByteBuffer?) {
        self.bytes = bytes
    }
}

// MARK: - ExpressibleByNilLiteral
extension MetadataValue: ExpressibleByNilLiteral {
    
    public init(nilLiteral: ()) {
        self.bytes = nil
    }
    
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMetadataValue(_ value: MetadataValue) -> Int {
        guard let bytes = value.bytes else {
            return self.writeNil()
        }
        return self.writeLiteral8(bytes.readableBytesView)
    }
}
