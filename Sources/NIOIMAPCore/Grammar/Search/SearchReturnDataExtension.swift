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

/// IMAPv4 `search-ret-data-ext`
public struct SearchReturnDataExtension: Equatable {
    public var modifier: String
    public var returnValue: TaggedExtensionValue

    public init(modifier: String, returnValue: TaggedExtensionValue) {
        self.modifier = modifier
        self.returnValue = returnValue
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeSearchReturnDataExtension(_ data: SearchReturnDataExtension) -> Int {
        self.writeTaggedExtensionLabel(data.modifier) +
            self.writeSpace() +
            self.writeTaggedExtensionValue(data.returnValue)
    }
}
