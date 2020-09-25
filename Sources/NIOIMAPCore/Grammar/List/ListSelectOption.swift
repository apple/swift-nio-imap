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

/// IMAPv4 `list-select-opt`
public enum ListSelectOption: Equatable {
    case base(ListSelectBaseOption)
    case independent(ListSelectIndependentOption)
    case modified(ListSelectModifiedOption)
}

public struct ListSelectOptions: Equatable {
    public var baseOption: ListSelectBaseOption
    public var options: [ListSelectOption]
    
    public init(baseOption: ListSelectBaseOption, options: [ListSelectOption]) {
        self.baseOption = baseOption
        self.options = options
    }
}

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListSelectOption(_ option: ListSelectOption) -> Int {
        switch option {
        case .base(let option):
            return self.writeListSelectBaseOption(option)
        case .independent(let option):
            return self.writeListSelectIndependentOption(option)
        case .modified(let option):
            return self.writeListSelectModifiedOption(option)
        }
    }

    @discardableResult mutating func writeListSelectOptions(_ options: ListSelectOptions?) -> Int {
        self.writeString("(") +
            self.writeIfExists(options) { (optionsData) -> Int in
                self.writeArray(optionsData.options, separator: "", parenthesis: false) { (option, self) -> Int in
                    self.writeListSelectOption(option) +
                        self.writeSpace()
                } +
                self.writeListSelectBaseOption(optionsData.baseOption)
            } +
            self.writeString(")")
    }
}
