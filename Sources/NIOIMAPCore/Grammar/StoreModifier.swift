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

/// Conditions that must be met in order for a server to perform a store operation
public enum StoreModifier: Hashable {
    /// If the mod-sequence of every metadata item of the
    /// message affected by the STORE/UID STORE is equal to or less than the
    /// specified UNCHANGEDSINCE value, then the requested operation (as
    /// described by the message data item) is performed.
    case unchangedSince(UnchangedSinceModifier)

    /// Designed as a catch-all to enable support for future extensions.
    case other(KeyValue<String, ParameterValue?>)
}

// MARK: - Encoding

extension EncodeBuffer {
    
    @discardableResult mutating func writeStoreModifiers(_ array: [StoreModifier]) -> Int {
        guard array.count > 0 else {
            return 0
        }
        
        return self.writeArray(array, prefix: " ", separator: " ", suffix: "", parenthesis: true) { (element, self) in
            self.writeStoreModifier(element)
        }
    }
    
    @discardableResult mutating func writeStoreModifier(_ val: StoreModifier) -> Int {
        switch val {
        case .unchangedSince(let unchangedSince):
            return self.writeUnchangedSinceModifier(unchangedSince)
        case .other(let param):
            return self.writeParameter(param)
        }
    }
}
