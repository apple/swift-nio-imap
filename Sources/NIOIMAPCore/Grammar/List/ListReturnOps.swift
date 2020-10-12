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

// MARK: - Encoding

extension EncodeBuffer {
    @discardableResult mutating func writeListReturnOptions(_ options: [ReturnOption]) -> Int {
        self.writeString("RETURN ") +
            self.writeString("(") +
            self.write(if: options.count >= 1, writer: {
                self.writeArray(options, parenthesis: false) { (option, self) in
                    self.writeReturnOption(option)
                }
            }) +
            self.writeString(")")
    }
}
