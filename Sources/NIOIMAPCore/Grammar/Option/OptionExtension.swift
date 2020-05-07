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

public enum OptionExtensionType: Equatable {
    case standard(String)
    case vendor(OptionVendorTag)
}

    /// IMAPv4 `option-extension`
    public struct OptionExtension: Equatable {
        public var type: OptionExtensionType
        public var value: OptionValueComp?

        public init(type: NIOIMAP.OptionExtensionType, value: NIOIMAP.OptionValueComp? = nil) {
            self.type = type
            self.value = value
        }
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeOptionExtension(_ option: OptionExtension) -> Int {
        var size = 0
        switch option.type {
        case .standard(let atom):
            size += self.writeString(atom)
        case .vendor(let tag):
            size += self.writeOptionVendorTag(tag)
        }

        if let value = option.value {
            size += self.writeSpace()
            size += self.writeOptionValue(value)
        }
        return size
    }
}
