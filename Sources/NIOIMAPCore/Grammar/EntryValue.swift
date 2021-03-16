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

extension _EncodeBuffer {
    @discardableResult mutating func writeEntry(_ entry: KeyValue<ByteBuffer, MetadataValue>) -> Int {
        self.writeIMAPString(entry.key) +
            self.writeSpace() +
            self.writeMetadataValue(entry.value)
    }

    @discardableResult mutating func writeEntryValues(_ array: KeyValues<ByteBuffer, MetadataValue>) -> Int {
        self.writeKeyValues(array) { element, buffer in
            buffer.writeEntry(element)
        }
    }

    @discardableResult mutating func writeEntries(_ array: [ByteBuffer]) -> Int {
        self.writeArray(array) { element, buffer in
            buffer.writeIMAPString(element)
        }
    }

    @discardableResult mutating func writeEntryList(_ array: [ByteBuffer]) -> Int {
        self.writeArray(array, parenthesis: false) { element, buffer in
            buffer.writeIMAPString(element)
        }
    }
}
