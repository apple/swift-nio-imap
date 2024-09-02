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

/// A percent-encoded section.
public struct EncodedSection: Hashable, Sendable {
    /// The percent-encoded data.
    public var section: String

    /// Creates a new `EncodedSection`.
    /// - parameter section: The percent-encoded string.
    public init(section: String) {
        self.section = section
    }
}

extension EncodeBuffer {
    @discardableResult mutating func writeEncodedSection(_ section: EncodedSection) -> Int {
        self.writeString(section.section)
    }
}
