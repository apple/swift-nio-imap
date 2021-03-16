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

/// Specifies the type of `OptionExtension`
public enum OptionExtensionKind: Hashable {
    /// A simple string-based value.
    case standard(String)

    /// Use a `OptionVendorTag` as the extension kind.
    case vendor(KeyValue<String, String>)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeOptionExtension(_ option: KeyValue<OptionExtensionKind, OptionValueComp?>) -> Int {
        var size = 0
        switch option.key {
        case .standard(let atom):
            size += self._writeString(atom)
        case .vendor(let tag):
            size += self.writeOptionVendorTag(tag)
        }

        if let value = option.value {
            size += self.writeSpace()
            size += self.writeOptionValue(value)
        }
        return size
    }

    @discardableResult mutating func writeOptionVendorTag(_ tag: KeyValue<String, String>) -> Int {
        self._writeString(tag.key) +
            self._writeString("-") +
            self._writeString(tag.value)
    }
}
