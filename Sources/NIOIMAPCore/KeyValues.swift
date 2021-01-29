//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftNIO open source project
//
// Copyright (c) 2021 Apple Inc. and the SwiftNIO project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftNIO project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

public struct KeyValues<K: Hashable, V: Hashable> {
    
    var _backing: [(K, V)]
    
    public init(_ array: [(K, V)] = []) {
        self._backing = array
    }
    
    public init(_ dic: [K: V]) {
        self._backing = dic.map { ($0.key, $0.value) }
    }
    
}

// MARK: - Hashable
extension KeyValues: Hashable {
    
    public func hash(into hasher: inout Hasher) {
        for (key, value) in self._backing {
            hasher.combine(key)
            hasher.combine(value)
        }
    }
    
}

// MARK: - Eqautable
extension KeyValues: Equatable {
    
    public static func == (lhs: KeyValues<K, V>, rhs: KeyValues<K, V>) -> Bool {
        return lhs._backing.map { $0.0 } == rhs._backing.map { $0.0 } && lhs._backing.map { $0.1 } == rhs._backing.map { $0.1 }
    }
    
}

// MARK: - ExpressibleByDictionaryLiteral
extension KeyValues: ExpressibleByDictionaryLiteral {

    public typealias Key = K
    
    public typealias Value = V

    public init(dictionaryLiteral elements: (K, V)...) {
        self._backing = elements
    }
}

// MARK: - Subscripting
extension KeyValues {
    
    subscript(index: K) -> V? {
        self._backing.first(where: { $0.0 == index })?.1
    }
    
}
