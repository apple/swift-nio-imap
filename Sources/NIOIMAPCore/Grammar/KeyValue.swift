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

/// Pairs a key with a value
public struct KeyValue<Key: Hashable, Value: Hashable>: Hashable {
    
    /// The key
    public var key: Key

    /// The value
    public var value: Value

    /// Creates a new `KeyValue`
    /// - parameter key: The key
    /// - parameter value: The value
    @inlinable
    public init(key: Key, value: Value) {
        self.key = key
        self.value = value
    }
}
