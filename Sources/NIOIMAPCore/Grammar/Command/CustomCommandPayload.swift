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

extension Command {
    public enum CustomCommandPayload: Hashable, Sendable {
        ///  This will be encoded using `quoted` or `literal`.
        case literal(ByteBuffer)
        /// This will be encoded _verbatim_, i.e. directly copied to the output buffer without change.
        case verbatim(ByteBuffer)
    }
}

// MARK: -

extension EncodeBuffer {
    /// Writes a `CustomCommandPayload` to the buffer ready to be sent to the network.
    /// - parameter stream: The `CustomCommandPayload` to write.
    /// - returns: The number of bytes written.
    @discardableResult public mutating func writeCustomCommandPayload(_ payload: Command.CustomCommandPayload) -> Int {
        switch payload {
        case .literal(let literal):
            return self.writeIMAPString(literal)
        case .verbatim(let verbatim):
            return self.writeBytes(verbatim.readableBytesView)
        }
    }
}
