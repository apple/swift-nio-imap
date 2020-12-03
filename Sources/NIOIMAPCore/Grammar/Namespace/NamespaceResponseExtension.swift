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

/// Designed as a catch-all to support namespace information contained in future IMAP extensions. Pairs a string key with an array of data.
public struct NamespaceResponseExtension: Equatable {
    
    /// A key
    public var string: ByteBuffer
    
    /// An array of data
    public var array: [ByteBuffer]

    /// Creates a new `NamespaceResponseExtension`.
    /// - parameter string: The `String` to use as a key.
    /// - parameter array: An associated array of data.
    public init(string: ByteBuffer, array: [ByteBuffer]) {
        self.string = string
        self.array = array
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeNamespaceResponseExtensions(_ extensions: [NamespaceResponseExtension]) -> Int {
        extensions.reduce(into: 0) { (res, ext) in
            res += self.writeNamespaceResponseExtension(ext)
        }
    }

    @discardableResult mutating func writeNamespaceResponseExtension(_ response: NamespaceResponseExtension) -> Int {
        self.writeSpace() +
            self.writeIMAPString(response.string) +
            self.writeSpace() +
            self.writeArray(response.array) { (string, self) in
                self.writeIMAPString(string)
            }
    }
}
