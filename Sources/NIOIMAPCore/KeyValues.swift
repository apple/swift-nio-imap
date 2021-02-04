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
public struct KeyValues<Key: Hashable, Value: Hashable>: Hashable {
    @usableFromInline
    var _backing: [KeyValue<Key, Value>]

    /// The number of key/value pairs in the collection.
    @inlinable
    public var count: Int { self._backing.count }

    /// Creates a new `KeyValues` from an array of key/value tuples.
    @inlinable
    public init(_ array: [(Key, Value)] = []) {
        self._backing = array.map { KeyValue(key: $0.0, value: $0.1) }
    }

    /// Creates a new `KeyValues` from a dictionary,
    @inlinable
    public init(_ dic: [Key: Value]) {
        self._backing = dic.map { KeyValue(key: $0.key, value: $0.value) }
    }

    /// Appends an element to the collection
    @inlinable
    public mutating func append(_ pair: (Key, Value)) {
        self._backing.append(KeyValue(key: pair.0, value: pair.1))
    }

    /// Appends an element to the collection
    @inlinable
    public mutating func append(_ pair: KeyValue<Key, Value>) {
        self._backing.append(pair)
    }
}

// MARK: - ExpressibleByDictionaryLiteral

extension KeyValues: ExpressibleByDictionaryLiteral {
    public typealias Key = Key

    public typealias Value = Value

    @inlinable
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self._backing = elements.map { KeyValue(key: $0.0, value: $0.1) }
    }
}

// MARK: - Subscripting

extension KeyValues {
    @inlinable
    subscript(key: Key) -> Value? {
        self._backing.first(where: { $0.key == key })?.value
    }
}

// MARK: - Sequence

extension KeyValues: Collection {
    public struct Index: Comparable {
        public static func < (lhs: KeyValues.Index, rhs: KeyValues.Index) -> Bool {
            lhs.index < rhs.index
        }

        internal var index: Int
    }

    public func index(after i: Index) -> Index {
        Index(index: self._backing.index(after: i.index))
    }

    public subscript(position: Index) -> (Key, Value) {
        return (self._backing[position.index].key, self._backing[position.index].value)
    }

    public var startIndex: Index {
        Index(index: self._backing.startIndex)
    }

    public var endIndex: Index {
        Index(index: self._backing.endIndex)
    }
}
