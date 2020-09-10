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

/// RFC2087 `setquota_resource`
public struct QuotaLimit: Equatable {
    public var resourceName: String
    public var limit: Int

    public init(resourceName: String, limit: Int) {
        self.resourceName = resourceName
        self.limit = limit
    }
}

// MARK: - Encoding
extension EncodeBuffer {
    @discardableResult mutating func writeQuotaLimit(_ quotaLimit: QuotaLimit) -> Int {
        self.writeAtom(quotaLimit.resourceName) +
            self.writeSpace() +
            self.writeString("\(quotaLimit.limit)")
    }
}
