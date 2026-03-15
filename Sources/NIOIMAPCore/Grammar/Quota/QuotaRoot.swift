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

/// A named quota root that groups resource limits for one or more mailboxes (RFC 2087).
///
/// **Requires server capability:** ``Capability/quota``
///
/// Each mailbox can have zero or more quota root associations. Mailboxes sharing the same quota root
/// share the same resource limits. Quota root names are implementation-defined atoms and do not necessarily
/// correspond to mailbox names. See [RFC 2087 Section 3](https://datatracker.ietf.org/doc/html/rfc2087#section-3) for details.
///
/// ### Example
///
/// ```
/// C: A001 GETQUOTA "user.john"
/// S: * QUOTA "user.john" (STORAGE 512000 102400)
/// S: A001 OK GETQUOTA completed
/// ```
///
/// The quota root name `"user.john"` (in double quotes) is represented as a ``QuotaRoot`` and appears in
/// ``QuotaResponse`` along with an array of ``QuotaResource`` values. This response is wrapped as
/// ``Response/untagged(_:)`` containing ``ResponsePayload/quotaData(_:_:)``.
///
/// ## Related Types
///
/// - See ``QuotaResource`` for resource usage and limits
/// - See ``QuotaRootResponse`` for mailbox-to-quota-root associations
/// - See ``ResponsePayload/quotaData(_:_:)`` for quota response data
///
/// - SeeAlso: [RFC 2087 Section 3](https://datatracker.ietf.org/doc/html/rfc2087#section-3)
public struct QuotaRoot: Hashable, Sendable {
    /// The raw bytes representing the quota root name.
    ///
    /// Contains the UTF-8 encoded bytes of the quota root name. Can be converted to a `String`
    /// via the initializer ``init(_:)-init:self`` operator.
    public var storage: ByteBuffer

    /// Creates a new `QuotaRoot` from a string.
    ///
    /// - parameter string: The quota root name as a string.
    public init(_ string: String) {
        self.storage = ByteBuffer(ByteBufferView(string.utf8))
    }

    /// Creates a new `QuotaRoot` from raw bytes.
    ///
    /// - parameter bytes: The raw `ByteBuffer` containing the quota root name bytes.
    public init(_ bytes: ByteBuffer) {
        self.storage = bytes
    }
}

extension String {
    /// Creates a string from a `QuotaRoot`.
    ///
    /// Attempts to decode the quota root bytes as UTF-8. Returns `nil` if the bytes are not valid UTF-8.
    ///
    /// - parameter other: The `QuotaRoot` to decode.
    public init?(_ other: QuotaRoot) {
        guard let string = String(validatingUTF8Bytes: other.storage.readableBytesView) else {
            return nil
        }
        self = string
    }
}

// MARK: - CustomDebugStringConvertible

extension QuotaRoot: CustomDebugStringConvertible {
    /// A human-readable representation of the root.
    public var debugDescription: String {
        // provide some debug information even if the buffer isn't valid UTF-8
        String(self) ?? String(buffer: self.storage)
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeQuotaRoot(_ quotaRoot: QuotaRoot) -> Int {
        self.writeIMAPString(quotaRoot.storage)
    }
}
