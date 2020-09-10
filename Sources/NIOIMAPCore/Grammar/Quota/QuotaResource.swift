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

/// RFC2087 `quota_resource`
public struct QuotaResource: Equatable {
    public var resourceName: String
    public var usage: Int
    public var limit: Int

    public init(resourceName: String, usage: Int, limit: Int) {
        self.resourceName = resourceName
        self.usage = usage
        self.limit = limit
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeQuotaResource(_ quotaDetails: QuotaResource) -> Int {
        self.writeAtom(quotaDetails.resourceName) +
            self.writeSpace() +
            self.writeString("\(quotaDetails.usage)") +
            self.writeSpace() +
            self.writeString("\(quotaDetails.limit)")
    }
}
