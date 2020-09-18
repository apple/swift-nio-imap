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

/// RFC 5464
public struct Entry: Equatable {
    public var name: ByteBuffer
    public var value: MetadataValue
    
    public init(name: ByteBuffer, value: MetadataValue) {
        self.name = name
        self.value = value
    }
}

extension EncodeBuffer {
    
    @discardableResult mutating func writeEntry(_ entry: Entry) -> Int {
        self.writeIMAPString(entry.name) +
            self.writeSpace() +
            self.writeMetadataValue(entry.value)
    }
    
    @discardableResult mutating func writeEntries(_ array: [Entry]) -> Int {
        self.writeArray(array) { element, buffer in
            buffer.writeEntry(element)
        }
    }
    
}
