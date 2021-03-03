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

public protocol LastCommandSetProtocol: Hashable {
 
    func writeIntoBuffer(_ buffer: inout EncodeBuffer) -> Int
    
}

public enum LastCommandSet<T: LastCommandSetProtocol>: Hashable {
    
    case set(T)
    
    case lastCommand
    
}

extension EncodeBuffer {
    
    @discardableResult mutating func writeLastCommandSet<T>(_ set: LastCommandSet<T>) -> Int {
        switch set {
        case .lastCommand:
            return self.writeString("$")
        case .set(let set):
            return set.writeIntoBuffer(&self)
        }
    }
    
}
