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

/// A non-standard vendor-specific option.
public struct OptionVendorTag: Hashable {
    /// The vendor identifier token.
    public var token: String

    /// The option.
    public var atom: String

    /// Creates a new `OptionVendorTag`
    /// - parameter token: The vendor identifier token.
    /// - parameter atom: The option
    public init(token: String, atom: String) {
        self.token = token
        self.atom = atom
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeOptionVendorTag(_ tag: OptionVendorTag) -> Int {
        self.writeString(tag.token) +
            self.writeString("-") +
            self.writeString(tag.atom)
    }
}
