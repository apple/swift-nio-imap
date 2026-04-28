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

/// A resource usage report showing current usage and maximum limit (RFC 2087).
///
/// **Requires server capability:** ``Capability/quota``
///
/// Quota resource data combines resource usage information with limit information,
/// allowing clients to understand both how much of a resource is currently in use and what the maximum
/// allowed usage is. This information is typically returned in server responses to quota commands.
/// See [RFC 2087 Section 5.1](https://datatracker.ietf.org/doc/html/rfc2087#section-5.1).
///
/// ### Example
///
/// ```
/// C: A001 GETQUOTA "user.john"
/// S: * QUOTA "user.john" (STORAGE 512000 102400 MESSAGE 450 500)
/// S: A001 OK GETQUOTA completed
/// ```
///
/// The response `(STORAGE 512000 102400 MESSAGE 450 500)` represents two ``QuotaResource`` instances:
/// - `STORAGE`: using 512000 KB out of 102400 KB limit (actually over limit - server implementation may vary)
/// - `MESSAGE`: 450 messages out of 500 message limit
///
/// These appear as part of the ``ResponsePayload/quota(_:_:)`` response.
///
/// ## Related types
///
/// - See ``QuotaLimit`` for just the maximum limit without usage
/// - See ``QuotaRoot`` for quota root names
///
/// - SeeAlso: [RFC 2087 Section 5.1](https://datatracker.ietf.org/doc/html/rfc2087#section-5.1)
public struct QuotaResource: Hashable, Sendable {
    /// The resource name being tracked.
    ///
    /// An atom identifying the resource type, such as `STORAGE` or `MESSAGE`. Custom resources
    /// may be defined by implementations.
    public var resourceName: String

    /// The current usage of the resource.
    ///
    /// For `STORAGE` resources, this is typically in units of 1024 octets (kilobytes).
    /// For `MESSAGE` resources, this is the current number of messages in the quota root.
    /// See [RFC 2087 Section 3](https://datatracker.ietf.org/doc/html/rfc2087#section-3).
    public var usage: Int

    /// The maximum allowed usage of the resource.
    ///
    /// When `usage` exceeds this limit, the quota root has exceeded its limit. Server behavior
    /// when limits are exceeded is implementation-defined.
    public var limit: Int

    /// Creates a new `QuotaResource` with current usage and maximum limit.
    ///
    /// - parameter resourceName: The resource name (for example, `"STORAGE"` or `"MESSAGE"`).
    /// - parameter usage: The current usage of the resource.
    /// - parameter limit: The maximum allowed value for the resource.
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
