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

/// Provides support for future extensions. Any future extensions to body fields must
/// match one case of this enum, either an `nstring` or `number`.
public enum BodyExtension: Equatable {
    /// A generic `nstring` field.
    case string(ByteBuffer?)

    /// A generic `number` field.
    case number(Int)
}

// MARK: - Encoding

extension _EncodeBuffer {
    @discardableResult mutating func writeBodyExtensions(_ ext: [BodyExtension]) -> Int {
        self.writeArray(ext) { (element, self) in
            self.writeBodyExtension(element)
        }
    }

    @discardableResult mutating func writeBodyExtension(_ type: BodyExtension) -> Int {
        switch type {
        case .string(let string):
            return self.writeNString(string)
        case .number(let number):
            return self._writeString("\(number)")
        }
    }
}
