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
public enum OptionExtensionKind: Equatable {
    
    /// A simple string-based value.
    case standard(String)
    
    /// Use a `OptionVendorTag` as the extension kind.
    case vendor(OptionVendorTag)
}

/// A catch-all wrapper to support future extensions. Acts as a key/value pair.
public struct OptionExtension: Equatable {
    
    /// Some option kind.
    public var kind: OptionExtensionKind
    
    /// Some options value.
    public var value: OptionValueComp?

    /// Creates a new `OptionExtension`.
    /// - parameter kind: The kind of option extension.
    /// - parameter value: The value of the extension. Defaults to `nil`.
    public init(kind: OptionExtensionKind, value: OptionValueComp? = nil) {
        self.kind = kind
        self.value = value
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeOptionExtension(_ option: OptionExtension) -> Int {
        var size = 0
        switch option.kind {
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
