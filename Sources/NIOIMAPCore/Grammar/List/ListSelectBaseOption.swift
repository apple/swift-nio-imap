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

    /// IMAPv4 `list-select-base-opt`
    public enum ListSelectBaseOption: Equatable {
        case subscribed
        case option(OptionExtension)
    }

}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeListSelectBaseOption(_ option: NIOIMAP.ListSelectBaseOption) -> Int {
        switch option {
        case .subscribed:
            return self.writeString("SUBSCRIBED")
        case .option(let option):
            return self.writeOptionExtension(option)
        }
    }

    @discardableResult mutating func writeListSelectBaseOptionQuoted(_ option: NIOIMAP.ListSelectBaseOption) -> Int {
        self.writeString("\"") +
        self.writeListSelectBaseOption(option) +
        self.writeString("\"")
    }

}
