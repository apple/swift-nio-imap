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
    
    /// IMAPv4 `capability`
    public enum Capability: Equatable {
        case auth(AuthType)
        case condStore
        case enable
        case move
        case literalPlus
        case literalMinus
        case filters
        case other(Atom)
    }
    
}

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
    
}
