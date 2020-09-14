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

/// RFC 7162
public enum StoreModifier: Equatable {
    
    case unchangedSince(UnchangedSinceModifier)
    
    case other(Parameter)
    
}

// MARK: - Encoding

extension EncodeBuffer {
    
    @discardableResult mutating func writeStoreModifier(_ val: StoreModifier) -> Int {
        switch val {
        case .unchangedSince(let unchangedSince):
            return self.writeUnchangedSinceModifier(unchangedSince)
        case .other(let param):
            return self.writeParameter(param)
        }
    }
    
}
