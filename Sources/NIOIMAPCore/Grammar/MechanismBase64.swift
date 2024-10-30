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

/// Pairs an authorization mechanism with base64-encoded authentication data.
public struct MechanismBase64: Hashable, Sendable {
    /// The authorization mechanism.
    public var mechanism: URLAuthenticationMechanism

    /// The authentication data, encoded as base64.
    public var base64: ByteBuffer?

    /// Creates a new `MechanismBase64`.
    /// - parameter mechanism: The authorization mechanism.
    /// - parameter base64: The authentication data, encoded as base64.
    public init(mechanism: URLAuthenticationMechanism, base64: ByteBuffer?) {
        self.mechanism = mechanism
        self.base64 = base64
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeMechanismBase64(_ data: MechanismBase64) -> Int {
        self.writeURLAuthenticationMechanism(data.mechanism)
            + self.writeIfExists(data.base64) { base64 in
                self.writeString("=") + self.writeBuffer(&base64)
            }
    }
}
