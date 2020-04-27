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

extension NIOIMAP {
    /// IMAPv4 `return-option`
    public enum ReturnOption: Equatable {
        case subscribed
        case children
        case statusOption([StatusAttribute])
        case optionExtension(OptionExtension)
    }
}

// MARK: - Encoding

extension ByteBuffer {
    @discardableResult mutating func writeReturnOption(_ option: NIOIMAP.ReturnOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .children:
            return self.writeString("CHILDREN")
        case .statusOption(let option):
            return self.writeStatusOption(option)
        case .optionExtension(let option):
            return self.writeOptionExtension(option)
        }
    }
}
