//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2026 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import NIO
import NIOIMAP

extension IMAPConnection {
    /// Sends continuation data to the server during authentication.
    public struct ContinuationWriter: ~Copyable {
        var underlying: OutboundQueue

        /// Sends the given bytes as a continuation response.
        public func writeContinuation(
            _ bytes: ByteBuffer
        ) async throws {
            try await underlying.writeContinuationResponse(bytes)
        }

        /// Sends the given byte sequence as a continuation response.
        public func writeContinuation(
            _ bytes: some Sequence<UInt8>
        ) async throws {
            try await writeContinuation(ByteBuffer(bytes: bytes))
        }
    }
}
