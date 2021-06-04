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

/// Used in the `.getMetadata` and `.setMetadata` commands.
public struct MetadataEntryName: Hashable {
    fileprivate var backing: ByteBuffer

    /// Creates a `MetadataEntryName` from a `ByteBuffer`.
    /// - parameter string: The raw `ByteBuffer`.
    public init(_ buffer: ByteBuffer) {
        self.backing = buffer
    }

    /// Creates a `MetadataEntryName` from a `String`.
    /// - parameter string: The raw `String`.
    public init(_ string: String) {
        self.backing = ByteBuffer(string: string)
    }
}

extension String {
    /// Creates a `String` from a `MetadataEntryName`
    /// - parameter metadataEntryName: The name to use.
    public init(_ metadataEntryName: MetadataEntryName) {
        self = String(buffer: metadataEntryName.backing)
    }
}

extension MetadataEntryName: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self.backing = ByteBuffer(string: value)
    }
}
