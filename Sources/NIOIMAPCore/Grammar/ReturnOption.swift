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

/// IMAPv4 `return-option`
public enum ReturnOption: Equatable {
    case subscribed
    case children
    case statusOption([MailboxAttribute])
    case optionExtension(OptionExtension)
    case specialUse
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeReturnOption(_ option: ReturnOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .children:
            return self.writeString("CHILDREN")
        case .statusOption(let option):
            return self.writeMailboxOptions(option)
        case .optionExtension(let option):
            return self.writeOptionExtension(option)
        case .specialUse:
            return self.writeString("SPECIAL-USE")
        }
    }
}
