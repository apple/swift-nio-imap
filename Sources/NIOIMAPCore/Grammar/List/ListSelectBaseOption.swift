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

/// Options that can be used by themselves.
public enum ListSelectBaseOption: Equatable {
    /// *SUBSCRIBED* - Lists subscribed mailboxes.
    case subscribed

    /// A catch-all to support future extensions
    case option(OptionExtension)
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListSelectBaseOption(_ option: ListSelectBaseOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .option(let option):
            return self.writeOptionExtension(option)
        }
    }

    @discardableResult mutating func writeListSelectBaseOptionQuoted(_ option: ListSelectBaseOption) -> Int {
        self.writeString("\"") +
            self.writeListSelectBaseOption(option) +
            self.writeString("\"")
    }
}
