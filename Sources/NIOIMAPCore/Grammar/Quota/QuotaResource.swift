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

/// A resource with it's current usage and maximum size.
public struct QuotaResource: Hashable, Sendable {
    /// The resource that the quota is applied to.
    public var resourceName: String

    /// How big the current resource is.
    public var usage: Int

    /// The maximum size/count of the resource.
    public var limit: Int

    /// Creates a new `QuotaResource`.
    /// - parameter resourceName: The resource that the quota is applied to.
    /// - parameter usage: How much os the resource is currently in use.
    /// - parameter limit: The maximum size/count of the resource.
    public init(resourceName: String, usage: Int, limit: Int) {
        self.resourceName = resourceName
        self.usage = usage
        self.limit = limit
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeQuotaResource(_ quotaDetails: QuotaResource) -> Int {
        self.writeAtom(quotaDetails.resourceName) + self.writeString(" \(quotaDetails.usage) \(quotaDetails.limit)")
    }
}
