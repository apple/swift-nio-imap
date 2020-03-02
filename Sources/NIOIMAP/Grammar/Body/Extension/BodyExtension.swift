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
    
    /// IMAPv4 `body-extension`
    public enum BodyExtension: Equatable {
        case string(NString)
        case number(Number)
        case array([BodyExtension])
    }
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyExtension(_ ext: NIOIMAP.BodyExtension) -> Int {
        switch ext {
        case .string(let string):
            return self.writeNString(string)
        case .number(let number):
            return self.writeString("\(number)")
        case .array(let array):
            return self.writeArray(array) { (element, self) in
                self.writeBodyExtension(element)
            }
        }
    }

}
