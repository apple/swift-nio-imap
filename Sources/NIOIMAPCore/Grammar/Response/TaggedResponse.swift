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

/// A tagged response that is sent by a server to signal that
/// a command has finished processing.
public struct TaggedResponse: Hashable, Sendable {
    /// The tag of the command that led to this response.
    public var tag: String

    /// Signals if the command was successfully executed.
    public var state: State

    /// Creates a new `TaggedResponse`.
    /// - parameter tag: The tag of the command that led to this response.
    /// - parameter state: Signals if the command was successfully executed.
    public init(tag: String, state: State) {
        self.tag = tag
        self.state = state
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedResponse(_ response: TaggedResponse) -> Int {
        self.writeString("\(response.tag) ") +
            self.writeTaggedResponseState(response.state) +
            self.writeString("\r\n")
    }
}
