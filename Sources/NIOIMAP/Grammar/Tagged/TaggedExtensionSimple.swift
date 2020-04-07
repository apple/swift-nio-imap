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

extension NIOIMAP {

    /// IMAPv4 `tagged-ext-simple`
    public enum TaggedExtensionSimple: Equatable {
        case sequence([NIOIMAP.SequenceRange])
        case number(Int)
        case number64(Int)
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeTaggedExtensionSimple(_ value: NIOIMAP.TaggedExtensionSimple) -> Int {
        switch value {
        case .sequence(let set):
            return self.writeSequenceSet(set)
        case .number(let num):
            return self.writeString("\(num)")
        case .number64(let num):
            return self.writeString("\(num)")
        }
    }

}
