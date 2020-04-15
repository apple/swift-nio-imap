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
    
    @discardableResult mutating func writeCapability(_ capability: NIOIMAP.Capability) -> Int {
        switch capability {
        case .auth(let type):
            return self.writeString("AUTH=\(type)")
        case .condStore:
            return self.writeString("CONDSTORE")
        case .enable:
            return self.writeString("ENABLE")
        case .move:
            return self.writeString("MOVE")
        case .literalPlus:
            return self.writeString("LITERAL+")
        case .literalMinus:
            return self.writeString("LITERAL-")
        case .filters:
            return self.writeString("FILTERS")
        case .other(let atom):
            return self.writeString(atom)
        }
    }
    
    @discardableResult mutating func writeCapabilityData(_ data: [NIOIMAP.Capability]) -> Int {
        self.writeString("CAPABILITY IMAP4 IMAP4rev1") +
        self.writeArray(data, separator: "", parenthesis: false) { (capability, self) -> Int in
            self.writeSpace() +
            self.writeCapability(capability)
        }
    }
    
}
