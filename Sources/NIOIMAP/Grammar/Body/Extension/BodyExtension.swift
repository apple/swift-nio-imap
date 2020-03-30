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
    public enum BodyExtensionType: Equatable {
        case string(NString)
        case number(Number)
    }
    
    public typealias BodyExtension = [BodyExtensionType]
    
}

// MARK: - Encoding
extension ByteBuffer {

    @discardableResult mutating func writeBodyExtension(_ ext: NIOIMAP.BodyExtension) -> Int {
        return self.writeArray(ext) { (element, self) in
            self.writeBodyExtensionType(element)
        }
    }
    
    @discardableResult mutating func writeBodyExtensionType(_ type: NIOIMAP.BodyExtensionType) -> Int {
        switch type {
        case .string(let string):
            return self.writeNString(string)
        case .number(let number):
            return self.writeString("\(number)")
        }
    }

}
