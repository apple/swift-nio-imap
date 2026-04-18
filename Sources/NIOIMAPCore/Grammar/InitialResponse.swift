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

/// An initial SASL response sent with the AUTHENTICATE command.
///
/// The SASL-IR extension (RFC 4959) allows clients to send an initial response directly with the
/// AUTHENTICATE command, rather than waiting for a server challenge. This reduces the number of
/// round-trips required for authentication.
///
/// The initial response is optional. An empty response is encoded as `=` (a single equals sign).
/// Non-empty responses are base64-encoded.
///
/// ### Example
///
/// ```
/// C: A001 AUTHENTICATE PLAIN dXNlcm5hbWVAZXhhbXBsZS5jb206cGFzc3dvcmQ=
/// S: A001 OK authenticated
/// ```
///
/// The client sends the AUTHENTICATE command with PLAIN mechanism and a base64-encoded initial
/// response containing username and password, avoiding the server challenge round-trip.
///
/// - SeeAlso: [RFC 4959 SASL Initial Response](https://datatracker.ietf.org/doc/html/rfc4959)
public struct InitialResponse: Hashable, Sendable {
    /// Creates a new empty `InitialResponse` that will be encoded as `=`.
    public static let empty: Self = .init(ByteBuffer())

    /// The data to be base-64 encoded.
    public var data: ByteBuffer

    /// Creates a new `InitialResponse`
    /// - parameter data: The raw (ie. not base64 encoded) data to be sent.
    public init(_ data: ByteBuffer) {
        self.data = data
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeInitialResponse(_ resp: InitialResponse) -> Int {
        guard resp.data.readableBytes == 0 else {
            let encoded = Base64.encodeBytes(bytes: resp.data.readableBytesView)
            return self.writeBytes(encoded)
        }
        return self.writeString("=")
    }
}
