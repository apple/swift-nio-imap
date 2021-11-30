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

/// Implemented as a catch-all to support types defined in future extensions.
public enum ParameterValue: Hashable {
    /// Specifies a `SequenceSet` as the value.
    case sequence(LastCommandSet<MessageIdentifierSet<SequenceNumber>>)

    /// Uses an array of `String` as the value.
    case comp([String])
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeParameterValue(_ value: ParameterValue) -> Int {
        switch value {
        case .sequence(let set):
            return self.writeLastCommandSet(set)
        case .comp(let comp):
            return
                self.writeString("(") +
                self.writeTaggedExtensionComp(comp) +
                self.writeString(")")
        }
    }
}
