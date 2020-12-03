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

/// A key/value wrapper to use as a catch-all to support future extensions to `MailboxInfo`
public struct ListExtendedItem: Equatable {
    
    /// The key
    public var tag: ByteBuffer
    
    /// The value.
    public var extensionValue: ParameterValue

    /// Creates a new `ListExtendedItem`
    /// - parameter tag: The key
    /// - parameter extensionValue: The value
    public init(tag: ByteBuffer, extensionValue: ParameterValue) {
        self.tag = tag
        self.extensionValue = extensionValue
    }
}
