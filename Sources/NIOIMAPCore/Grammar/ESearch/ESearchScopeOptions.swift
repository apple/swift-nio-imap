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

/// RFC 6237 - One or more scope options
public struct ESearchScopeOptions: Equatable {
    /// Array of at least one scope option.
    public private(set) var content: [ESearchScopeOption]

    /// Initialise - there must be at least one scope option in the set.
    ///  - parameter options: One or more mailboxes.
    init?(_ options: [ESearchScopeOption]) {
        guard options.count >= 1 else {
            return nil
        }
        self.content = options
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult public mutating func writeESearchScopeOptions(_ options: ESearchScopeOptions) -> Int {
        self.writeArray(options.content, parenthesis: false) { (option, buffer) -> Int in
            buffer.writeESearchScopeOption(option)
        }
    }
}
