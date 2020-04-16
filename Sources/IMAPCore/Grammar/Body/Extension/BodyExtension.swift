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

extension IMAPCore {
    
    /// IMAPv4 `body-extension`
    public enum BodyExtensionType: Equatable {
        case string(NString)
        case number(Int)
    }
    
}

// MARK: - Encoding
extension ByteBufferProtocol {

    @discardableResult mutating func writeBodyExtension(_ ext: [IMAPCore.BodyExtensionType]) -> Int {
        return self.writeArray(ext) { (element, self) in
            self.writeBodyExtensionType(element)
        }
    }
    
    @discardableResult mutating func writeBodyExtensionType(_ type: IMAPCore.BodyExtensionType) -> Int {
        switch type {
        case .string(let string):
            return self.writeNString(string)
        case .number(let number):
            return self.writeString("\(number)")
        }
    }

}
