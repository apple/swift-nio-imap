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

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeSearchReturnOption(_ option: NIOIMAP.SearchReturnOption) -> Int {
        switch option {
        case .min:
            return self.writeString("MIN")
        case .max:
            return self.writeString("MAX")
        case .all:
            return self.writeString("ALL")
        case .count:
            return self.writeString("COUNT")
        case .save:
            return self.writeString("SAVE")
        case .optionExtension(let option):
            return self.writeSearchReturnOptionExtension(option)
        }
    }

    @discardableResult mutating func writeSearchReturnOptions(_ options: [NIOIMAP.SearchReturnOption]) -> Int {
        guard options.count > 0 else {
            return 0
        }
        return
            self.writeString(" RETURN (") +
            self.writeIfExists(options) { (options) -> Int in
                self.writeArray(options, parenthesis: false) { (option, self) in
                    self.writeSearchReturnOption(option)
                }
            } +
            self.writeString(")")
    }

}
