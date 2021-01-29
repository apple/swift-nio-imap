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

/// A dictionary-like structure that preserves insert order, and provides O(n) lookup based on some `Key`
public struct KeyValues<Key: Hashable, Value: Hashable> {
    var _backing: [(Key, Value)]

    /// The number of key/value pairs in the collection.
    public var count: Int { self._backing.count }

    /// Creates a new `KeyValues` from an array of key/value tuples.
    public init(_ array: [(Key, Value)] = []) {
        self._backing = array
    }

    /// Creates a new `KeyValues` from a dictionary,
    public init(_ dic: [Key: Value]) {
        self._backing = dic.map { ($0.key, $0.value) }
    }

    /// Appends an element to the collection
    public mutating func append(_ pair: (Key, Value)) {
        self._backing.append(pair)
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
    public static func == (lhs: KeyValues<Key, Value>, rhs: KeyValues<Key, Value>) -> Bool {
        lhs._backing.map { $0.0 } == rhs._backing.map { $0.0 } && lhs._backing.map { $0.1 } == rhs._backing.map { $0.1 }
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension KeyValues: ExpressibleByDictionaryLiteral {
    public typealias Key = Key

    public typealias Value = Value

    public init(dictionaryLiteral elements: (Key, Value)...) {
        self._backing = elements
    }
}

// MARK: - Subscripting

extension KeyValues {
    subscript(index: Key) -> Value? {
        self._backing.first(where: { $0.0 == index })?.1
    }
}

// MARK: - Sequence

extension KeyValues: Sequence {
    public typealias Iterator = IndexingIterator<[(Key, Value)]>

    public typealias Element = (Key, Value)

    public func makeIterator() -> IndexingIterator<[(Key, Value)]> {
        self._backing.makeIterator()
    }
}
