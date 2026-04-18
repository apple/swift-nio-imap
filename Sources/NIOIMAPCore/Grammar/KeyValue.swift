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

/// A generic key-value pair container.
///
/// This generic type is used throughout the IMAP protocol implementation to pair related values,
/// such as extension names with their parameters, vendor tags with their values, or tagged
/// extension data with their content.
///
/// - SeeAlso: ``OptionExtensionKind/vendor(_:)``
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

extension KeyValue: Sendable where Key: Sendable, Value: Sendable {}
