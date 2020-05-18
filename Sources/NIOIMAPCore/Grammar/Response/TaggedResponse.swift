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

/// IMAPv4 `response-tagged`
public struct TaggedResponse: Equatable {
    public var tag: String
    public var state: ResponseConditionalState

    public init(tag: String, state: ResponseConditionalState) {
        self.tag = tag
        self.state = state
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeTaggedResponse(_ response: TaggedResponse) -> Int {
        self.writeString("\(response.tag) ") +
            self.writeResponseConditionalState(response.state) +
            self.writeString("\r\n")
    }
}
