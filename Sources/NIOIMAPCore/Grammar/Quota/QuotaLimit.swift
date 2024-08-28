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

/// A resource with it's corresponding limits.
public struct QuotaLimit: Hashable, Sendable {
    /// The resource that the quota is applied to.
    public var resourceName: String

    /// The maximum size/count of the resource.
    public var limit: Int

    /// Creates a new `QuotaLimit`.
    /// - parameter resourceName: The resource that the quota is applied to.
    /// - parameter limit: The maximum size/count of the resource.
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
