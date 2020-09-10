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
import struct NIO.ByteBufferView

/// RFC2087 quota root
public struct QuotaRoot: Equatable {
    /// The raw bytes, readable as `[UInt8]`
    public var storage: ByteBuffer

    /// The raw bytes decoded into a UTF8 `String`
    public var stringValue: String {
        String(buffer: self.storage)
    }

    /// Creates a new `QuotaRoot`.
    ///  - parameter string: The quota root name
    public init(_ string: String) {
        self.storage = ByteBuffer(ByteBufferView(string.utf8))
    }

    public init(_ bytes: ByteBuffer) {
        self.storage = bytes
    }
}

// MARK: - CustomStringConvertible

extension QuotaRoot: CustomStringConvertible {
    public var description: String {
        self.stringValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult public mutating func writeQuotaRoot(_ quotaRoot: QuotaRoot) -> Int {
        self.writeIMAPString(quotaRoot.storage)
    }
}
