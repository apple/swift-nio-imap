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

/// A resource quota limit specifying the maximum allowed size or count for a resource (RFC 2087).
///
/// **Requires server capability:** ``Capability/quota``
///
/// Quota limits define the maximum allowed value for a named resource within a quota root. Common resources
/// include `STORAGE` (maximum mailbox size in kilobytes) and `MESSAGE` (maximum number of messages).
/// Each resource has an atom name and an implementation-defined numeric limit.
/// See [RFC 2087 Section 4.1](https://datatracker.ietf.org/doc/html/rfc2087#section-4.1) for details.
///
/// ### Example
///
/// ```
/// C: A001 GETQUOTA "user.john"
/// S: * QUOTA "user.john" (STORAGE 512000 102400 MESSAGE 1000 500)
/// S: A001 OK GETQUOTA completed
/// ```
///
/// In this response, `STORAGE 512000 102400` represents two ``QuotaLimit`` instances:
/// - Resource `STORAGE` with limit `102400` (kilobytes)
/// - Resource `MESSAGE` with limit `500` (messages)
///
/// These appear as part of the ``ResponsePayload/quota(_:_:)`` response.
///
/// ## Related Types
///
/// - See ``QuotaResource`` for current usage along with limits
/// - See ``QuotaRoot`` for quota root names
///
/// - SeeAlso: [RFC 2087 Section 5.1](https://datatracker.ietf.org/doc/html/rfc2087#section-5.1)
public struct QuotaLimit: Hashable, Sendable {
    /// The resource name that the quota limit applies to.
    ///
    /// An atom identifying the resource type, such as `STORAGE` or `MESSAGE`. Custom resources
    /// may be defined by implementations.
    public var resourceName: String

    /// The maximum allowed size or count for the resource.
    ///
    /// For `STORAGE` resources, this is typically in units of 1024 octets (kilobytes).
    /// For `MESSAGE` resources, this is the maximum number of messages allowed in the quota root.
    /// See [RFC 2087 Section 3](https://datatracker.ietf.org/doc/html/rfc2087#section-3) for standard resources.
    public var limit: Int

    /// Creates a new `QuotaLimit` with a resource name and maximum limit.
    ///
    /// - parameter resourceName: The resource name (e.g., `"STORAGE"`, `"MESSAGE"`).
    /// - parameter limit: The maximum allowed value for the resource.
    public init(resourceName: String, limit: Int) {
        self.resourceName = resourceName
        self.limit = limit
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeQuotaLimit(_ quotaLimit: QuotaLimit) -> Int {
        self.writeAtom(quotaLimit.resourceName) + self.writeSpace() + self.writeString("\(quotaLimit.limit)")
    }
}
