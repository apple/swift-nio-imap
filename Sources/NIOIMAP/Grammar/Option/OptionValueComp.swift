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
import IMAPCore

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeOptionValue(_ value: IMAPCore.OptionValueComp) -> Int {
        self.writeString("(") +
        self.writeOptionValueComp(value) +
        self.writeString(")")
    }

    @discardableResult mutating func writeOptionValueComp(_ option: IMAPCore.OptionValueComp) -> Int {
        switch option {
        case .string(let string):
            return self.writeIMAPString(string)
        case .array(let array):
            return self.writeArray(array) { (option, self) in
                self.writeOptionValueComp(option)
            }
        }
    }

}
