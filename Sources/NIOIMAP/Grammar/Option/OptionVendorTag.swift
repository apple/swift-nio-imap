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

import NIO

extension NIOIMAP {

    /// IMAPv4 `option-vendor-tag`
    public struct OptionVendorTag: Equatable {
        public var token: String
        public var atom: String

        public static func token(_ token: String, atom: String) -> Self {
            return Self(token: token, atom: atom)
        }
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeOptionVendorTag(_ tag: NIOIMAP.OptionVendorTag) -> Int {
        self.writeString(tag.token) +
        self.writeString("-") +
        self.writeString(tag.atom)
    }

}
