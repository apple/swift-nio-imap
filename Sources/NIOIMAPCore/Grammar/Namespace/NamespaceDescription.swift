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

/// Represents an IMAP Namespace, providing a delimiter to
/// break the namespace into it's constituent components.
public struct NamespaceDescription: Equatable {
    /// The full namespace string.
    public var string: ByteBuffer

    /// A hierarchy delimiter.
    public var delimiter: Character?

    /// A catch-all to provide support fo future extensions.
    public var responseExtensions: KeyValues<ByteBuffer, [ByteBuffer]>

    /// Creates a new `NamespaceDescription`.
    /// - parameter string: The full namespace string.
    /// - parameter char: A hierarchy delimiter.
    /// - parameter responseExtensions: A catch-all to provide support fo future extensions.
    public init(string: ByteBuffer, char: Character? = nil, responseExtensions: KeyValues<ByteBuffer, [ByteBuffer]>) {
        self.string = string
        self.delimiter = char
        self.responseExtensions = responseExtensions
    }
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeNamespaceDescription(_ description: NamespaceDescription) -> Int {
        var size = 0
        size += self._writeString("(")
        size += self.writeIMAPString(description.string)
        size += self.writeSpace()

        if let char = description.delimiter {
            size += self._writeString("\"\(char)\"")
        } else {
            size += self.writeNil()
        }

        size += self.writeNamespaceResponseExtensions(description.responseExtensions)
        size += self._writeString(")")
        return size
    }
}
