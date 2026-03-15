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

/// The `ENABLED` response data sent by a server in response to an `ENABLE` command (RFC 5161).
///
/// **Requires server capability:** ``Capability/enable``
///
/// The `ENABLED` response reports which extension capabilities have been successfully enabled
/// by the server. This allows clients to know which extensions are now active on the connection.
/// The server responds to the `ENABLE` command with zero or more capabilities that were enabled.
/// From [RFC 5161 Section 3.1](https://datatracker.ietf.org/doc/html/rfc5161#section-3.1).
///
/// ### Example
///
/// ```
/// C: A001 ENABLE CONDSTORE QRESYNC
/// S: * ENABLED CONDSTORE QRESYNC
/// S: A001 OK ENABLE completed
/// ```
///
/// The line `S: * ENABLED CONDSTORE QRESYNC` is wrapped as ``Response/untagged(_:)`` containing
/// ``ResponsePayload/enableData(_:)`` with an array of enabled ``Capability`` values.
///
/// - SeeAlso: [RFC 5161](https://datatracker.ietf.org/doc/html/rfc5161)
typealias EnableData = [Capability]

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeEnableData(_ data: [Capability]) -> Int {
        self.writeString("ENABLED")
            + data.reduce(0) { (result, capability) in
                result + self.writeSpace() + self.writeCapability(capability)
            }
    }
}
